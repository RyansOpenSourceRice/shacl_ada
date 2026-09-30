--  SPDX-License-Identifier: Apache-2.0
--
--  Constraint evaluation engine of the SPARK core.
--
--  Evaluates the SHACL 1.0 Core constraint components over a bounded
--  data graph and records violations. Property shapes evaluate predicate
--  paths only; path expressions are a separate milestone. Shape-link
--  recursion (sh:not, sh:and/sh:or/sh:xone members, sh:node,
--  sh:qualifiedValueShape, sh:property) is bounded by Max_Depth. The
--  violation capacity is a generic formal parameter, sized by the
--  application like the data-graph capacity. No exceptions are raised;
--  this unit is pure SPARK.

with SHACL_Ada.Data;
with SHACL_Ada.Shapes;
with SHACL_Ada.Terms;
with SHACL_Ada.Validation;

generic

   --  Number of violations one Violation_Table of this instantiation
   --  records. Validate stops recording beyond it; check Saturated to
   --  detect that the budget was too small.
   Max_Violations : Positive;

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
      Depth     : Natural;
      Count     : Natural;
      Target    : in out Violation_Table;
      Emit      : Boolean;
      Ok        : in out Boolean)
   with Pre  => Depth < Max_Depth,
        Post => Target.Count >= Target.Count'Old;

end SHACL_Ada.Eval;
