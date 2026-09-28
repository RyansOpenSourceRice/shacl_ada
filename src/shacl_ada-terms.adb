--  SPDX-License-Identifier: Apache-2.0

package body SHACL_Ada.Terms with SPARK_Mode is

   function To_Text (Value : String) return Text is
      Result : Text;
   begin
      Result.Size := Value'Length;
      Result.Data (1 .. Value'Length) := Value;
      return Result;
   end To_Text;

   function Length (Value : Text) return Natural is
     (Value.Size);

   function Image (Value : Text) return String is
     (Value.Data (1 .. Value.Size));

   function Empty return Term is
     (Term'(Kind     => Iri,
            Name     => <>,
            Lexical  => <>,
            Language => <>,
            Datatype => <>));

   function Is_Empty (Value : Term) return Boolean is
     (Value.Kind = Iri and then Length (Value.Name) = 0);

   function Make_Iri (Value : String) return Term is
     (Term'(Kind     => Iri,
            Name     => To_Text (Value),
            Lexical  => <>,
            Language => <>,
            Datatype => <>));

   function Make_Blank_Node (Label : String) return Term is
     (Term'(Kind     => Blank_Node,
            Name     => To_Text (Label),
            Lexical  => <>,
            Language => <>,
            Datatype => <>));

   function Make_Literal
     (Lexical  : String;
      Language : String := "";
      Datatype : String := "") return Term
   is
     (Term'(Kind     => Literal,
            Name     => <>,
            Lexical  => To_Text (Lexical),
            Language => To_Text (Language),
            Datatype => To_Text (Datatype)));

   function Kind_Of (Value : Term) return Term_Kind is
     (Value.Kind);

   function Name_Of (Value : Term) return String is
     (Image (Value.Name));

   function Lexical_Of (Value : Term) return String is
     (Image (Value.Lexical));

   function Language_Of (Value : Term) return String is
     (Image (Value.Language));

   function Datatype_Of (Value : Term) return String is
     (Image (Value.Datatype));

end SHACL_Ada.Terms;
