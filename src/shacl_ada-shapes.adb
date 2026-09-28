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

end SHACL_Ada.Shapes;
