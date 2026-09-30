--  SPDX-License-Identifier: Apache-2.0
--
--  Bounded data-graph model of the SPARK core.
--
--  A Graph holds the triples of one default data graph as bounded terms.
--  The capacity is a generic formal parameter: applications instantiate
--  this package with the triple budget their deployment can afford (the
--  same pattern as SPARK's bounded formal containers), so no library
--  constant caps someone else's dataset. Instances are multi-megabyte
--  records; allocate them in heap or static storage, never on a
--  default-size stack. This unit is pure SPARK.

with SHACL_Ada.Terms;

generic

   --  Number of triples a Graph of this instantiation stores.
   Max_Triples : Positive;

package SHACL_Ada.Data with SPARK_Mode is

   type Triple is record
      Subject   : Terms.Term := Terms.Empty;
      Predicate : Terms.Term := Terms.Empty;
      Object    : Terms.Term := Terms.Empty;
   end record;

   type Triple_Array is array (1 .. Max_Triples) of Triple;

   type Graph is record
      List  : Triple_Array;
      Count : Natural range 0 .. Max_Triples := 0;
   end record;

   function Capacity return Natural is (Max_Triples);

   function Count_Of (Value : Graph) return Natural is (Value.Count);

   --  True when no further triple can be inserted.
   function Full (Value : Graph) return Boolean is (Value.Count = Max_Triples);

   procedure Insert (Into : in out Graph; Value : Triple) with
     Pre  => not Full (Into),
     Post => Into.Count = Into.Count'Old + 1;

   --  The Index-th stored triple (1-based).
   function Element (Value : Graph; Index : Positive) return Triple with
     Pre => Index <= Value.Count;

end SHACL_Ada.Data;
