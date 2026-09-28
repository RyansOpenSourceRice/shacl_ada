--  SPDX-License-Identifier: Apache-2.0
--
--  Bounded term model of the SPARK core.
--
--  Every text payload (IRI, blank-node label, lexical form, language tag,
--  datatype IRI) is stored in a fixed-capacity record, so the whole model
--  lives in stack or static storage with no heap and no I/O. This unit is
--  pure SPARK: gnatprove proves absence of runtime errors.

package SHACL_Ada.Terms with SPARK_Mode is

   --  Longest IRI, blank-node label, lexical form, language tag, or
   --  datatype IRI this library stores.
   Max_Text_Length : constant := 512;

   type Text is private;

   function To_Text (Value : String) return Text with
     Pre => Value'Length <= Max_Text_Length;

   function Length (Value : Text) return Natural;

   function Image (Value : Text) return String with
     Post => Image'Result'Length = Length (Value);

   type Term_Kind is (Iri, Blank_Node, Literal);

   type Term is private;

   --  IRI term with an empty value. Marks the absence of a term; no query
   --  should treat it as data.
   function Empty return Term;

   function Is_Empty (Value : Term) return Boolean;

   function Make_Iri (Value : String) return Term with
     Pre => Value'Length <= Max_Text_Length;

   function Make_Blank_Node (Label : String) return Term with
     Pre => Label'Length <= Max_Text_Length;

   function Make_Literal
     (Lexical  : String;
      Language : String := "";
      Datatype : String := "") return Term
     with Pre => Lexical'Length <= Max_Text_Length
                 and then Language'Length <= Max_Text_Length
                 and then Datatype'Length <= Max_Text_Length;

   function Kind_Of (Value : Term) return Term_Kind;

   --  IRI value for Iri terms, blank-node label for Blank_Node terms.
   function Name_Of (Value : Term) return String;

   function Lexical_Of (Value : Term) return String;

   function Language_Of (Value : Term) return String;

   --  Datatype IRI; empty for plain literals.
   function Datatype_Of (Value : Term) return String;

private

   type Text is record
      Size : Natural range 0 .. Max_Text_Length := 0;
      Data : String (1 .. Max_Text_Length) := (others => ' ');
   end record;

   type Term is record
      Kind     : Term_Kind := Iri;
      Name     : Text;
      Lexical  : Text;
      Language : Text;
      Datatype : Text;
   end record;

end SHACL_Ada.Terms;
