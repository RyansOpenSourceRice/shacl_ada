--  SPDX-License-Identifier: Apache-2.0
--
--  Internal violation model of the SPARK core.
--
--  One validation result of the evaluation engine. This is the engine's
--  own record, not the sh:ValidationResult vocabulary; the report
--  milestone maps these records onto the Recommendation's result terms.

with SHACL_Ada.Shapes;
with SHACL_Ada.Terms;

package SHACL_Ada.Validation with SPARK_Mode is

   type Violation is record
      Focus_Node   : Terms.Term := Terms.Empty;
      Value_Node   : Terms.Term := Terms.Empty;
      Path         : Terms.Term := Terms.Empty;
      Source_Shape : Terms.Term := Terms.Empty;
      Component    : Shapes.Constraint_Kind := Shapes.Min_Count;
   end record;

end SHACL_Ada.Validation;
