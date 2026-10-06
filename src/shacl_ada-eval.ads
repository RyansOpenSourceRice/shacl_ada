--  SPDX-License-Identifier: Apache-2.0
--
--  Constraint evaluation engine of the SPARK core.
--
--  Evaluates the SHACL 1.0 Core constraint components over a bounded
--  data graph and records violations. Property shapes evaluate the full
--  SHACL 1.0 Core path grammar (§6): predicate, inverse, sequence,
--  alternative, and the three cardinality forms, as a bounded path
--  AST in the shapes model. Shape-link recursion (sh:not,
--  sh:and/sh:or/sh:xone members, sh:node, sh:qualifiedValueShape,
--  sh:property) is bounded by Max_Depth; the path walker is bounded by
--  a step fuel. The violation and distinct-value capacities are
--  generic formal parameters, sized by the application like the
--  data-graph capacity. No exceptions are raised; this unit is pure
--  SPARK.

with SHACL_Ada.Data;
with SHACL_Ada.Shapes;
with SHACL_Ada.Terms;
with SHACL_Ada.Validation;

generic

   --  Number of violations one Violation_Table of this instantiation
   --  records. Validate stops recording beyond it; check Saturated to
   --  detect that the budget was too small.
   Max_Violations : Positive;

   --  Number of distinct value nodes one path computation of this
   --  instantiation records. A path yielding more evaluates over the
   --  recorded prefix; the computation's Overflow flag reports it.
   Max_Path_Values : Positive;

   --  The data-graph instantiation the engine evaluates over.
   with package Data is new SHACL_Ada.Data (<>);

package SHACL_Ada.Eval with SPARK_Mode is

   --  Shape-link recursion bound. Deep shapes graphs (chains of sh:node,
   --  sh:property, boolean connectives) evaluate only to this depth;
   --  deeper references conform vacuously.
   Max_Depth : constant := 8;

   type Violation_Array is array (1 .. Max_Violations) of Validation.Violation;

   type Violation_Table is record
      List  : Violation_Array;
      Count : Natural range 0 .. Max_Violations := 0;
   end record;

   --  True when validation produced no violation.
   function Conforms (Result : Violation_Table) return Boolean is
     (Result.Count = 0);

   --  True when the violation budget was exhausted and results may be
   --  incomplete. Grow Max_Violations and revalidate.
   function Saturated (Result : Violation_Table) return Boolean is
     (Result.Count = Max_Violations);

   --  Evaluate every targeted shape of Shape_Set over Graph and append
   --  the violations to Into (existing entries are preserved; duplicate
   --  results from overlapping targets are recorded once).
    procedure Validate
      (Shape_Set : Shapes.Shape_Table;
       Graph     : Data.Graph;
        Into      : in out Violation_Table) with
      Post => Into.Count >= Into.Count'Old;

private

   --  Path-expression evaluation state -------------------------------

   --  Total work items (node, path-node) pairs one path computation
   --  may process. Bounds the walker against cyclic data and the
   --  exponential branching of alternatives.
   Max_Path_Work : constant := 512;

   --  Path-node expansion chain. One item means: walk the path node
   --  Step from Node; the values it yields continue with the path node
   --  Next, whose values continue with Next2. Step zero with all
   --  continuations zero means Node is a final value.
   type Work_Item is record
      Node  : Terms.Term := Terms.Empty;
      Step  : Natural    := 0;
      Next  : Natural    := 0;
      Next2 : Natural    := 0;
   end record;

   type Work_Array is array (1 .. Max_Path_Work) of Work_Item;

   type Work_State is record
      List      : Work_Array;
      First     : Natural range 1 .. Max_Path_Work + 1 := 1;
      Last      : Natural range 0 .. Max_Path_Work := 0;
      Steps     : Natural range 0 .. Max_Path_Work := 0;
      Exhausted : Boolean := False;
   end record;

   --  Worklist of one path computation. It is reused sequentially:
   --  every Path_Values call completes before the next one starts.
   Work : Work_State := (List => (others => <>), others => <>);

   --  The distinct value nodes of one path computation over one focus
   --  node. Overflow reports that the value budget or the step fuel
   --  ran out; evaluation proceeds over the recorded prefix.
   type Value_Array is array (1 .. Max_Path_Values) of Terms.Term;

   type Value_Set is record
      List     : Value_Array;
      Count    : Natural range 0 .. Max_Path_Values := 0;
      Overflow : Boolean := False;
   end record;

   procedure Append_Value (Values : in out Value_Set; Item : Terms.Term) with
     Post => Values.Count <= Values.Count'Old + 1;

   --  Depth guard for the two path-structure walks below; also bounds
   --  them over malformed tables whose child links could cycle.
   Path_Depth_Limit : constant := 64;

   --  The distinct value nodes the path with root index Root yields
   --  from From over Graph. A root of zero (ill-formed path) yields
   --  the empty set.
   procedure Path_Values
     (From      : Terms.Term;
      Root      : Natural;
      Graph     : Data.Graph;
      Shape_Set : Shapes.Shape_Table;
      Values    : out Value_Set);

   --  True when the predicate IRI occurs anywhere in the path with
   --  root index Root — the leaf predicates of the path grammar, the
   --  predicate set of sh:closed.
   function Path_Has_Predicate
     (Shape_Set : Shapes.Shape_Table;
      Root      : Natural;
      Want      : Terms.Term;
      Depth     : Natural) return Boolean
   with Subprogram_Variant => (Decreases => Depth);

   --  Structural equality of the paths rooted at A and B.
   function Same_Path
     (Shape_Set : Shapes.Shape_Table; A, B : Natural; Depth : Natural)
      return Boolean
   with Subprogram_Variant => (Decreases => Depth);

   --  Internal evaluation steps. Declared in the private part so each
   --  is proven standalone with its contract at call sites rather than
   --  being re-analyzed inside every caller's context.

   procedure Check_Value_Constraints
     (Value            : Terms.Term;
      Shape            : Shapes.Shape;
      Focus            : Terms.Term;
      Graph            : Data.Graph;
      Shape_Set        : Shapes.Shape_Table;
      Depth            : Natural;
      Property_Context : Boolean;
      Target           : in out Violation_Table;
      Emit             : Boolean;
      Ok               : out Boolean)
   with Pre  => Depth <= Max_Depth,
        Post => Target.Count >= Target.Count'Old;

   procedure Check_Node
     (Node      : Terms.Term;
      Idx       : Positive;
      Graph     : Data.Graph;
      Shape_Set : Shapes.Shape_Table;
      Depth     : Natural;
      Target    : in out Violation_Table;
      Emit      : Boolean;
      Ok        : out Boolean)
   with Pre  => Idx <= Shape_Set.Count and then Depth <= Max_Depth,
        Post => Target.Count >= Target.Count'Old;

   procedure Check_Property
     (Focus     : Terms.Term;
      Idx       : Positive;
      Graph     : Data.Graph;
      Shape_Set : Shapes.Shape_Table;
      Depth     : Natural;
      Target    : in out Violation_Table;
      Emit      : Boolean;
      Ok        : out Boolean)
   with Pre  => Idx <= Shape_Set.Count and then Depth <= Max_Depth,
        Post => Target.Count >= Target.Count'Old;

   procedure Conforms_To_Ref
     (Node      : Terms.Term;
      Shape_Set : Shapes.Shape_Table;
      Ref_Node  : Terms.Term;
      Graph     : Data.Graph;
      Depth     : Natural;
      Target    : in out Violation_Table;
      Ok        : out Boolean)
   with Post => Target.Count >= Target.Count'Old;

   procedure Check_Kind
     (K         : Shapes.Constraint_Kind;
      Value     : Terms.Term;
      Shape     : Shapes.Shape;
      Focus     : Terms.Term;
      Graph     : Data.Graph;
      Shape_Set : Shapes.Shape_Table;
      Depth     : Natural;
      Target    : in out Violation_Table;
      Emit      : Boolean;
      Ok        : in out Boolean)
   with Post => Target.Count >= Target.Count'Old;

   procedure Check_Connectives
     (Value     : Terms.Term;
      Shape     : Shapes.Shape;
      Focus     : Terms.Term;
      Graph     : Data.Graph;
      Shape_Set : Shapes.Shape_Table;
      Depth     : Natural;
      Target    : in out Violation_Table;
      Emit      : Boolean;
      Ok        : in out Boolean)
   with Post => Target.Count >= Target.Count'Old;

   procedure Check_Qualified
     (Shape     : Shapes.Shape;
      Focus     : Terms.Term;
      Graph     : Data.Graph;
      Shape_Set : Shapes.Shape_Table;
      Values    : Value_Set;
      Depth     : Natural;
      Target    : in out Violation_Table;
      Emit      : Boolean;
      Ok        : in out Boolean)
   with Pre  => Depth < Max_Depth,
        Post => Target.Count >= Target.Count'Old;

end SHACL_Ada.Eval;
