--  SPDX-License-Identifier: Apache-2.0
--
--  Shapes-graph model of the SPARK core.
--
--  A Shape_Table holds every node shape and property shape of one shapes
--  graph, with its targets and the Core constraint parameters attached to
--  it. All bounds are published constants; a table plus its shapes live in
--  static or heap storage, never on a default-size stack (a table is a few
--  megabytes). This unit is pure SPARK.

with SHACL_Ada.Terms;

package SHACL_Ada.Shapes with SPARK_Mode is

   Max_Shapes                 : constant := 64;
   Max_Targets_Per_Shape      : constant := 16;
   Max_Constraints_Per_Shape  : constant := 16;

   type Target_Kind is
     (Target_Node, Target_Class, Target_Subjects_Of, Target_Objects_Of);

   type Constraint_Kind is
     (Min_Count, Max_Count,
      Min_Exclusive, Max_Exclusive, Min_Inclusive, Max_Inclusive,
      Min_Length, Max_Length, Pattern_Param, Language_In, Unique_Lang,
      Datatype_Param, Equals_Param, Disjoint_Param,
      Less_Than, Less_Than_Or_Equals,
      Closed_Param, Ignored_Property, Has_Value_Param, In_Member,
      Qualified_Value_Shape, Qualified_Shapes_Disjoint,
      Qualified_Min_Count, Qualified_Max_Count,
      Not_Shape, And_Shape, Or_Shape, Xone_Shape,
      Node_Link, Property_Link,
      Class_Param, Node_Kind_Param);

   type Target is record
      Kind  : Target_Kind := Target_Node;
      Value : Terms.Term  := Terms.Empty;
   end record;

   --  One constraint parameter occurrence. Value carries the parameter
   --  term; Extra carries a companion parameter such as sh:flags on a
   --  sh:pattern, or is empty.
   type Constraint is record
      Kind  : Constraint_Kind := Min_Count;
      Value : Terms.Term      := Terms.Empty;
      Extra : Terms.Term      := Terms.Empty;
   end record;

   type Target_Array is array (1 .. Max_Targets_Per_Shape) of Target;
   type Constraint_Array is array (1 .. Max_Constraints_Per_Shape) of Constraint;

   type Shape is record
      Node              : Terms.Term := Terms.Empty;
      Is_Property_Shape : Boolean    := False;
      Has_Path          : Boolean    := False;
      Path              : Terms.Term := Terms.Empty;
      Targets           : Target_Array;
      Target_Count      : Natural range 0 .. Max_Targets_Per_Shape := 0;
      Constraints       : Constraint_Array;
      Constraint_Count  : Natural range 0 .. Max_Constraints_Per_Shape := 0;
      Deactivated       : Boolean    := False;
   end record;

   type Shape_Array is array (1 .. Max_Shapes) of Shape;

   type Shape_Table is record
      List  : Shape_Array;
      Count : Natural range 0 .. Max_Shapes := 0;
   end record;

   --  Index of the shape with this node, or 0 when absent.
   function Find (Table : Shape_Table; Node : Terms.Term) return Natural with
     Post => (if Find'Result > 0 then Find'Result <= Table.Count);

end SHACL_Ada.Shapes;
