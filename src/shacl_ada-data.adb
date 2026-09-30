--  SPDX-License-Identifier: Apache-2.0

package body SHACL_Ada.Data with SPARK_Mode is

   procedure Insert (Into : in out Graph; Value : Triple) is
   begin
      Into.Count := Into.Count + 1;
      Into.List (Into.Count) := Value;
   end Insert;

   function Element (Value : Graph; Index : Positive) return Triple is
     (Value.List (Index));

end SHACL_Ada.Data;
