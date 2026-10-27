--  SPDX-License-Identifier: Apache-2.0
--
--  Violation model of the SPARK core: one Validation record carries
--  the Recommendation's sh:ValidationResult terms the engine can
--  state — focus node, value node, result path, source shape and
--  constraint component (mandatory), plus severity and message.
--  Serialization to RDF triples lives outside the core.

with SHACL_Ada.Shapes;
with SHACL_Ada.Terms;

package SHACL_Ada.Validation with SPARK_Mode is

   --  The report is explicit about capacity: recording stops at the
   --  caller's budget instead of silently truncating. Dropped counts
   --  the distinct results that did not fit; grow the budget to at
   --  least Total_Results and revalidate for the complete report.
   type Error_Kind is (None, Capacity_Exceeded);

   --  Follow-up results linked from a parent (sh:detail). Indices into
   --  the same table; 0 is empty. Tables only append, so stored
   --  indices stay valid for the call.
   Max_Details : constant := 4;

   type Detail_Array is array (1 .. Max_Details) of Natural;

   type Violation is record
      Focus_Node   : Terms.Term := Terms.Empty;
      Value_Node   : Terms.Term := Terms.Empty;
      Path         : Terms.Term := Terms.Empty;
      Source_Shape : Terms.Term := Terms.Empty;
      Component    : Shapes.Constraint_Kind := Shapes.Min_Count;
      --  Report vocabulary (§5). Severity copies the shape's
      --  sh:severity; Message is the shape's first sh:message when
      --  present, else the engine's fixed text for the component.
      Severity     : Shapes.Severity_Kind := Shapes.Severity_Violation;
      Message      : Terms.Term := Terms.Empty;
      Detail_Count : Natural range 0 .. Max_Details := 0;
      Details      : Detail_Array := (others => 0);
   end record;

end SHACL_Ada.Validation;
