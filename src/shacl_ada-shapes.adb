--  SPDX-License-Identifier: Apache-2.0

package body SHACL_Ada.Shapes with SPARK_Mode is

   function Find (Table : Shape_Table; Node : Terms.Term) return Natural is
      use type Terms.Term;
   begin
      for Index in 1 .. Table.Count loop
         if Table.List (Index).Node = Node then
            return Index;
         end if;
      end loop;
      return 0;
   end Find;

   procedure Add_Path_Node
     (Table : in out Shape_Table; Node : Path_Node; Index : out Natural)
   is
   begin
      if Table.Path_Count >= Max_Path_Nodes then
         Index := 0;
      else
         Table.Path_Count := Table.Path_Count + 1;
         Table.Paths (Table.Path_Count) := Node;
         Index := Table.Path_Count;
      end if;
   end Add_Path_Node;

end SHACL_Ada.Shapes;
