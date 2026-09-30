--  SPDX-License-Identifier: Apache-2.0

package body SHACL_Ada.Eval with SPARK_Mode is

   use type Terms.Term;
   use type Terms.Term_Kind;
   use type Shapes.Constraint_Kind;
   use type Validation.Violation;

   Rdf_Ns        : constant String := "http://www.w3.org/1999/02/22-rdf-syntax-ns#";
   Rdfs_Ns       : constant String := "http://www.w3.org/2000/01/rdf-schema#";
   Xsd_Ns        : constant String := "http://www.w3.org/2001/XMLSchema#";

   Rdf_Type_Term      : constant Terms.Term := Terms.Make_Iri (Rdf_Ns & "type");
   Rdfs_Class_Term    : constant Terms.Term := Terms.Make_Iri (Rdfs_Ns & "Class");
   Rdfs_Subclass_Term : constant Terms.Term := Terms.Make_Iri (Rdfs_Ns & "subClassOf");
   Rdf_Type_Name      : constant String := Rdf_Ns & "type";

   Lang_String : constant String := Rdf_Ns & "langString";
   Xsd_String  : constant String := Xsd_Ns & "string";

   Sh_Iri        : constant String := "http://www.w3.org/ns/shacl#IRI";
   Sh_Blank_Node : constant String := "http://www.w3.org/ns/shacl#BlankNode";
   Sh_Literal    : constant String := "http://www.w3.org/ns/shacl#Literal";
   Sh_Bn_Or_Iri  : constant String := "http://www.w3.org/ns/shacl#BlankNodeOrIRI";
   Sh_Bn_Or_Lit  : constant String := "http://www.w3.org/ns/shacl#BlankNodeOrLiteral";
   Sh_Iri_Or_Lit : constant String := "http://www.w3.org/ns/shacl#IRIOrLiteral";

   function Same (A, B : Terms.Term) return Boolean is (A = B);

   --  ------------------------------------------------------------------
   --  Graph scan helpers
   --  ------------------------------------------------------------------

   function Object_Matches
     (Graph : Data.Graph; S, P, Wanted : Terms.Term) return Boolean
   is (for some I in 1 .. Graph.Count =>
         Same (Data.Element (Graph, I).Subject, S)
         and then Same (Data.Element (Graph, I).Predicate, P)
         and then Same (Data.Element (Graph, I).Object, Wanted));

   function Value_Count (Graph : Data.Graph; S, P : Terms.Term) return Natural is
      Total : Natural := 0;
   begin
      for I in 1 .. Graph.Count loop
         pragma Loop_Invariant (Total <= I - 1);
         declare
            T : constant Data.Triple := Data.Element (Graph, I);
         begin
            if Same (T.Subject, S) and then Same (T.Predicate, P) then
               Total := Total + 1;
            end if;
         end;
      end loop;
      return Total;
   end Value_Count;

   --  The N-th object (1-based) of (S, P, *), or Empty when absent.
   function Nth_Object
     (Graph : Data.Graph; S, P : Terms.Term; N : Positive) return Terms.Term
   is
      Seen : Natural := 0;
   begin
      for I in 1 .. Graph.Count loop
         pragma Loop_Invariant (Seen <= I - 1);
         declare
            T : constant Data.Triple := Data.Element (Graph, I);
         begin
            if Same (T.Subject, S) and then Same (T.Predicate, P) then
               Seen := Seen + 1;
               if Seen = N then
                  return T.Object;
               end if;
            end if;
         end;
      end loop;
      return Terms.Empty;
   end Nth_Object;

   --  rdfs:subClassOf* reachability inside the data graph, depth-bound.
   function Subclass_Reaches
     (Graph : Data.Graph; From, To : Terms.Term; Depth : Natural) return Boolean
   with Subprogram_Variant => (Decreases => Depth)
   is
   begin
      if Depth = 0 then
         return False;
      end if;
      for I in 1 .. Graph.Count loop
         declare
            T : constant Data.Triple := Data.Element (Graph, I);
         begin
            if Same (T.Subject, From)
              and then Same (T.Predicate, Rdfs_Subclass_Term)
            then
               if Same (T.Object, To) then
                  return True;
               end if;
               if Subclass_Reaches (Graph, T.Object, To, Depth - 1) then
                  return True;
               end if;
            end if;
         end;
      end loop;
      return False;
   end Subclass_Reaches;

   --  SHACL instance: rdf:type Class, or rdf:type of a subclass thereof.
   function Is_Instance
     (Graph : Data.Graph; Node, Class : Terms.Term) return Boolean
   is
   begin
      for I in 1 .. Graph.Count loop
         declare
            T : constant Data.Triple := Data.Element (Graph, I);
         begin
            if Same (T.Subject, Node)
              and then Same (T.Predicate, Rdf_Type_Term)
            then
               if Same (T.Object, Class) then
                  return True;
               end if;
               if Subclass_Reaches (Graph, T.Object, Class, Max_Depth) then
                  return True;
               end if;
            end if;
         end;
      end loop;
      return False;
   end Is_Instance;

   --  ------------------------------------------------------------------
   --  Small string helpers
   --  ------------------------------------------------------------------

   function To_Lower (C : Character) return Character is
     (if C in 'A' .. 'Z'
      then Character'Val (Character'Pos (C) + 32) else C);

   function Fold_Equal (A, B : String) return Boolean is
   begin
      if A'Length /= B'Length then
         return False;
      end if;
      for K in 0 .. A'Length - 1 loop
         if To_Lower (A (A'First + K)) /= To_Lower (B (B'First + K)) then
            return False;
         end if;
      end loop;
      return True;
   end Fold_Equal;

   function Contains (S, Needle : String) return Boolean is
   begin
      if Needle'Length = 0 or else Needle'Length > S'Length then
         return False;
      end if;
      for K in 0 .. S'Length - Needle'Length loop
         pragma Loop_Invariant (S'First + K <= S'Last - Needle'Length + 1);
         if Fold_Equal (S (S'First + K .. S'First + K + Needle'Length - 1),
                        Needle)
         then
            return True;
         end if;
      end loop;
      return False;
   end Contains;

   --  Number of Unicode codepoints in a UTF-8 byte string.
   function Codepoints (S : String) return Natural is
      N : Natural := 0;
   begin
      for K in S'Range loop
         pragma Loop_Invariant (N <= K - S'First + 1);
         declare
            B : constant Natural := Character'Pos (S (K));
         begin
            if B < 16#80# or else B > 16#BF# then
               N := N + 1;
            end if;
         end;
      end loop;
      return N;
   end Codepoints;

   --  Codepoint-wise string comparison (SPARQL simple-literal order).
   function Lex_Less (A, B : String; Or_Equal : Boolean) return Boolean is
      N : constant Natural := (if A'Length < B'Length then A'Length else B'Length);
   begin
      for K in 0 .. N - 1 loop
         declare
            CA : constant Character := A (A'First + K);
            CB : constant Character := B (B'First + K);
         begin
            if CA /= CB then
               return CA < CB;
            end if;
         end;
      end loop;
      return (if Or_Equal then A'Length <= B'Length else A'Length < B'Length);
   end Lex_Less;

   --  Nonnegative integer parameter of a constraint (sh:minCount, ...).
   --  Unparsable parameters yield 0, which makes length/count checks pass
   --  vacuously rather than misfire.
   function Param_Count (Value : Terms.Term) return Natural is
      Lex : constant String := Terms.Lexical_Of (Value);
      Result : Natural := 0;
   begin
      for K in Lex'Range loop
         if Lex (K) not in '0' .. '9' then
            return 0;
         end if;
         if Result < (Natural'Last / 10) - 1 then
            Result := Result * 10 + (Character'Pos (Lex (K)) - Character'Pos ('0'));
         end if;
      end loop;
      return Result;
   end Param_Count;

   --  ------------------------------------------------------------------
   --  XSD numeric parsing and comparison
   --  ------------------------------------------------------------------

   --  Value = Mantissa * 10**Exponent, with the mantissa capped at 18
   --  significant digits (Long_Long_Integer range). Larger lexicals
   --  compare approximately; the corpus and ordinary datasets are exact.
   Exponent_Limit : constant := 16#10_0000#;  --  2**20

   subtype Exponent_Value is Integer range -Exponent_Limit .. Exponent_Limit;

   type Parsed_Number is record
      Valid    : Boolean := False;
      Mantissa : Long_Long_Integer := 0;
      Exponent : Exponent_Value := 0;
   end record;

   function Is_Numeric_Datatype (Name : String) return Boolean is
      Local : constant String :=
        (if Name'Length > Xsd_Ns'Length
           and then Name (Name'First .. Name'First + Xsd_Ns'Length - 1)
                    = Xsd_Ns
         then Name (Name'First + Xsd_Ns'Length .. Name'Last)
         else "");
   begin
      return
        Local = "integer"              or else Local = "decimal"
        or else Local = "float"        or else Local = "double"
        or else Local = "long"         or else Local = "int"
        or else Local = "short"        or else Local = "byte"
        or else Local = "nonNegativeInteger"
        or else Local = "nonPositiveInteger"
        or else Local = "negativeInteger"
        or else Local = "positiveInteger"
        or else Local = "unsignedLong" or else Local = "unsignedInt"
        or else Local = "unsignedShort" or else Local = "unsignedByte";
   end Is_Numeric_Datatype;

   Mantissa_Digits : constant := 18;

   function Parse_Number (Lexical : String) return Parsed_Number with
     Pre => Lexical'First = 1
            and then Lexical'Last < Natural'Last
            and then Lexical'Length <= Terms.Max_Text_Length
   is
      Pos         : Natural := Lexical'First;
      Negative    : Boolean := False;
      Result      : Parsed_Number;
      Digit_Count : Natural := 0;

      procedure Absorb_Digit (D : Character) with
        Pre  => D in '0' .. '9' and then Result.Mantissa >= 0,
        Post => Result.Mantissa >= 0
                and then Result.Exponent = Result.Exponent'Old
      is
         Digit : constant Long_Long_Integer :=
           Long_Long_Integer (Character'Pos (D) - Character'Pos ('0'));
      begin
         if Digit_Count < Mantissa_Digits then
            Digit_Count := Digit_Count + 1;
            if Result.Mantissa
              <= (Long_Long_Integer'Last - Digit) / 10
            then
               Result.Mantissa := Result.Mantissa * 10 + Digit;
            end if;
         end if;
      end Absorb_Digit;

   begin
      if Pos > Lexical'Last then
         return Result;
      end if;
      if Lexical (Pos) = '+' then
         Pos := Pos + 1;
      elsif Lexical (Pos) = '-' then
         Negative := True;
         Pos := Pos + 1;
      end if;
      declare
         Any_Digit : Boolean := False;
      begin
         for Idx in Pos .. Lexical'Last loop
            pragma Loop_Invariant
              (Pos >= Lexical'First
               and then Pos <= Lexical'Last + 1
               and then Result.Mantissa >= 0
               and then Result.Exponent = Result'Loop_Entry.Exponent);
            Pos := Idx;
            exit when Lexical (Idx) not in '0' .. '9';
            Any_Digit := True;
            Absorb_Digit (Lexical (Idx));
            Pos := Idx + 1;
         end loop;
         if Pos <= Lexical'Last and then Lexical (Pos) = '.' then
            declare
               Start_Pos : constant Natural := Pos + 1;
               Start_Exp : constant Exponent_Value := Result.Exponent;
            begin
               Pos := Pos + 1;
               for Idx in Pos .. Lexical'Last loop
                  pragma Loop_Invariant (Pos = Idx);
                  pragma Loop_Invariant
                    (Start_Exp = 0
                     and then Start_Exp - Result.Exponent = Pos - Start_Pos
                     and then Result.Exponent <= 0
                     and then Result.Exponent >= -Terms.Max_Text_Length
                     and then Result.Mantissa >= 0);
                  Pos := Idx;
                  exit when Lexical (Idx) not in '0' .. '9';
                  Any_Digit := True;
                  Result.Exponent := Result.Exponent - 1;
                  Absorb_Digit (Lexical (Idx));
                  Pos := Idx + 1;
               end loop;
            end;
         end if;
         if not Any_Digit then
            return Result;
         end if;
         if Pos <= Lexical'Last
           and then (Lexical (Pos) = 'e' or Lexical (Pos) = 'E')
         then
            declare
               E_Pos   : Natural := Pos + 1;
               E_Neg   : Boolean := False;
               E_Value : Natural := 0;
            begin
               if E_Pos > Lexical'Last then
                  return Result;
               end if;
               if Lexical (E_Pos) = '+' then
                  E_Pos := E_Pos + 1;
               elsif Lexical (E_Pos) = '-' then
                  E_Neg := True;
                  E_Pos := E_Pos + 1;
               end if;
               if E_Pos > Lexical'Last
                 or else Lexical (E_Pos) not in '0' .. '9'
               then
                  return Result;
               end if;
               for Idx in E_Pos .. Lexical'Last loop
                  pragma Loop_Invariant (E_Value <= 1_000_000);
                  exit when Lexical (Idx) not in '0' .. '9';
                  if E_Value < 100_000 then
                     E_Value :=
                       E_Value * 10
                       + (Character'Pos (Lexical (Idx))
                          - Character'Pos ('0'));
                  end if;
                  E_Pos := Idx + 1;
               end loop;
               Pos := E_Pos;
               if E_Neg then
                  Result.Exponent := Result.Exponent + E_Value;
               else
                  Result.Exponent := Result.Exponent - E_Value;
               end if;
            end;
         end if;
         if Pos <= Lexical'Last then
            return Result;  -- trailing junk (INF, NaN, ...)
         end if;
      end;
      if Negative and then Result.Mantissa > Long_Long_Integer'First then
         Result.Mantissa := -Result.Mantissa;
      end if;
      Result.Valid := True;
      return Result;
   end Parse_Number;

   --  Powers of ten up to 10**18, as literals so the provers see each
   --  result exactly instead of reasoning about exponentiation.
   function Pow10 (N : Natural) return Long_Long_Integer with
     Pre  => N <= 18,
     Post => Pow10'Result >= 1
   is
   begin
      return (case N is
         when 0      => 1,
         when 1      => 10,
         when 2      => 100,
         when 3      => 1_000,
         when 4      => 10_000,
         when 5      => 100_000,
         when 6      => 1_000_000,
         when 7      => 10_000_000,
         when 8      => 100_000_000,
         when 9      => 1_000_000_000,
         when 10     => 10_000_000_000,
         when 11     => 100_000_000_000,
         when 12     => 1_000_000_000_000,
         when 13     => 10_000_000_000_000,
         when 14     => 100_000_000_000_000,
         when 15     => 1_000_000_000_000_000,
         when 16     => 10_000_000_000_000_000,
         when 17     => 100_000_000_000_000_000,
         when others => 1_000_000_000_000_000_000);
   end Pow10;

   --  Sign of the comparison; requires both valid.
   function Compare_Numbers (A, B : Parsed_Number) return Integer with
     Pre => A.Valid and then B.Valid
   is
   begin
      if A.Mantissa = 0 and then B.Mantissa = 0 then
         return 0;
      end if;
      if A.Mantissa = 0 then
         return (if B.Mantissa < 0 then 1 else -1);
      end if;
      if B.Mantissa = 0 then
         return (if A.Mantissa > 0 then 1 else -1);
      end if;
      if (A.Mantissa > 0) /= (B.Mantissa > 0) then
         return (if A.Mantissa > 0 then 1 else -1);
      end if;
      declare
         Diff : constant Integer := A.Exponent - B.Exponent;
      begin
         if Diff = 0 then
            if A.Mantissa = B.Mantissa then
               return 0;
            end if;
            return (if A.Mantissa > B.Mantissa then 1 else -1);
         end if;
         --  With |Mantissa| < 10**18, an exponent lead of 19 or more is
         --  decisive: the smaller-exponent side is below 10**Exponent.
         if Diff >= 19 then
            return (if A.Mantissa > 0 then 1 else -1);
         end if;
         if Diff <= -19 then
            return (if B.Mantissa > 0 then -1 else 1);
         end if;
         if Diff > 0 then
            declare
               Scale : constant Long_Long_Integer := Pow10 (Diff);
            begin
               if A.Mantissa > Long_Long_Integer'Last / Scale
                 or else A.Mantissa < Long_Long_Integer'First / Scale
               then
                  return (if A.Mantissa > 0 then 1 else -1);
               end if;
               declare
                  Scaled : constant Long_Long_Integer := A.Mantissa * Scale;
               begin
                  if Scaled = B.Mantissa then
                     return 0;
                  end if;
                  return (if Scaled > B.Mantissa then 1 else -1);
               end;
            end;
         else
            declare
               Scale : constant Long_Long_Integer := Pow10 (-Diff);
            begin
               if B.Mantissa > Long_Long_Integer'Last / Scale
                 or else B.Mantissa < Long_Long_Integer'First / Scale
               then
                  return (if B.Mantissa > 0 then -1 else 1);
               end if;
               declare
                  Scaled : constant Long_Long_Integer := B.Mantissa * Scale;
               begin
                  if A.Mantissa = Scaled then
                     return 0;
                  end if;
                  return (if A.Mantissa > Scaled then 1 else -1);
               end;
            end;
         end if;
      end;
   end Compare_Numbers;

   --  Numeric view of a term: literals with a numeric datatype only.
   function Numeric_Of (Value : Terms.Term) return Parsed_Number is
      Raw : Parsed_Number;
   begin
      if Terms.Kind_Of (Value) = Terms.Literal
        and then Is_Numeric_Datatype (Terms.Datatype_Of (Value))
      then
         Raw := Parse_Number (Terms.Lexical_Of (Value));
      end if;
      return Raw;
   end Numeric_Of;

   --  ------------------------------------------------------------------
   --  Pattern matching (bounded subset of XSD regex)
   --  ------------------------------------------------------------------

   --  Supported syntax: literals, '.', character classes '[...]' with
   --  ranges, negation and backslash escapes, '^'/'$' anchors, the
   --  quantifiers '*' '+' '?', and alternation-free concatenation. The
   --  only flag honored is 'i' (case-insensitive). Everything else
   --  matches literally or fails, which is documented in DESIGN.md.

   Match_Depth_Limit : constant := 4096;

   type Match_Step is record
      Ok   : Boolean := False;
      Next : Natural := 0;
   end record;

   function Class_Matches
     (P           : String;
      Start       : Positive;
      C           : Character;
      Insensitive : Boolean) return Match_Step
   with Pre  => P'First <= Start
                and then Start <= P'Last
                and then P'Last < Natural'Last,
        Post => P'First <= Class_Matches'Result.Next
                and then Class_Matches'Result.Next <= P'Last + 1
   is
      Pos     : Natural := Start + 1;
      Negated : Boolean := False;
      Found   : Boolean := False;
      Ch      : constant Character :=
        (if Insensitive then To_Lower (C) else C);
   begin
      if Pos > P'Last then
         return (Ok => False, Next => P'Last + 1);
      end if;
      if P (Pos) = '^' then
         Negated := True;
         Pos := Pos + 1;
      end if;
      for Idx in Pos .. P'Last loop
         Pos := Idx;
         exit when P (Idx) = ']';
         declare
            Lo : constant Character :=
              (if Insensitive then To_Lower (P (Idx)) else P (Idx));
         begin
            Pos := Idx + 1;
            if Pos <= P'Last and then P (Pos) = '-'
              and then Pos + 1 <= P'Last
              and then P (Pos + 1) /= ']'
            then
               declare
                  Hi : constant Character :=
                    (if Insensitive then To_Lower (P (Pos + 1)) else P (Pos + 1));
               begin
                  Pos := Pos + 2;
                  if Ch >= Lo and then Ch <= Hi then
                     Found := True;
                  end if;
               end;
            else
               if Ch = Lo then
                  Found := True;
               end if;
               if Lo = '-' and then Ch = '-' then
                  Found := True;
               end if;
            end if;
         end;
      end loop;
      return (Ok => False, Next => P'Last + 1);
   end Class_Matches;

   function Atom_Matches
     (P           : String;
      Pos         : Positive;
      C           : Character;
      Insensitive : Boolean) return Match_Step
   with Pre  => P'First <= Pos
                and then Pos <= P'Last
                and then P'Last < Natural'Last,
        Post => P'First <= Atom_Matches'Result.Next
                and then Atom_Matches'Result.Next <= P'Last + 1
   is
      Ch : constant Character := (if Insensitive then To_Lower (C) else C);
      Pc : constant Character :=
        (if Insensitive then To_Lower (P (Pos)) else P (Pos));
      Result : Match_Step;
   begin
      case P (Pos) is
         when '.' =>
            Result := (Ok => True, Next => Pos + 1);
         when '[' =>
            Result := Class_Matches (P, Pos, C, Insensitive);
         when '\' =>
            if Pos + 1 <= P'Last then
               Result :=
                 (Ok => Ch = (if Insensitive
                              then To_Lower (P (Pos + 1)) else P (Pos + 1)),
                  Next => Pos + 2);
            else
               Result := (Ok => False, Next => Pos + 1);
            end if;
         when '^' | '$' | '*' | '+' | '?' =>
            Result := (Ok => False, Next => Pos + 1);
         when others =>
            Result := (Ok => Ch = Pc, Next => Pos + 1);
      end case;
      return Result;
   end Atom_Matches;

   function Match_Here
     (P           : String;
      PI          : Natural;
      S           : String;
      SI          : Natural;
      Insensitive : Boolean;
      Depth       : Natural) return Boolean
   with Pre  => P'Last < Natural'Last
                and then S'Last < Natural'Last
                and then P'First >= 1
                and then S'First >= 1
                and then P'First <= PI
                and then PI <= P'Last + 1
                and then S'First <= SI,
        Subprogram_Variant => (Decreases => Depth)
   is
   begin
      if Depth = 0 then
         return False;
      end if;
      if PI > P'Last then
         return True;
      end if;
      if P (PI) = '$' then
         return SI > S'Last
           and then Match_Here (P, PI + 1, S, SI, Insensitive, Depth - 1);
      end if;
      declare
         Quant : Character := ' ';
      begin
         if PI + 1 <= P'Last and then P (PI + 1) in '*' | '+' | '?' then
            Quant := P (PI + 1);
         end if;
         case Quant is
            when '*' =>
               if Match_Here (P, PI + 2, S, SI, Insensitive, Depth - 1) then
                  return True;
               end if;
                for J in SI .. S'Last loop
                   exit when not Atom_Matches (P, PI, S (J), Insensitive).Ok;
                   if Match_Here
                       (P, PI + 2, S, J + 1, Insensitive, Depth - 1)
                   then
                      return True;
                   end if;
                end loop;
                return False;
            when '+' =>
               if SI > S'Last then
                  return False;
               end if;
               if not Atom_Matches (P, PI, S (SI), Insensitive).Ok then
                  return False;
               end if;
               if Match_Here
                   (P, PI + 2, S, SI + 1, Insensitive, Depth - 1)
               then
                  return True;
               end if;
               for J in SI + 1 .. S'Last loop
                  exit when not Atom_Matches (P, PI, S (J), Insensitive).Ok;
                  if Match_Here
                      (P, PI + 2, S, J + 1, Insensitive, Depth - 1)
                  then
                     return True;
                  end if;
               end loop;
               return False;
             when '?' =>
               if Match_Here (P, PI + 2, S, SI, Insensitive, Depth - 1) then
                  return True;
               end if;
               if SI <= S'Last
                 and then Atom_Matches (P, PI, S (SI), Insensitive).Ok
                 and then Match_Here
                            (P, PI + 2, S, SI + 1, Insensitive, Depth - 1)
               then
                  return True;
               end if;
               return False;
            when others =>
               if SI > S'Last then
                  return False;
               end if;
               declare
                  Step : constant Match_Step :=
                    Atom_Matches (P, PI, S (SI), Insensitive);
               begin
                  if Step.Ok then
                     return Match_Here
                       (P, Step.Next, S, SI + 1, Insensitive, Depth - 1);
                  end if;
               end;
               return False;
         end case;
      end;
   end Match_Here;

   function Regex_Matches
     (Pattern : String; Value : String; Insensitive : Boolean) return Boolean
   with Pre => Pattern'Last < Natural'Last
               and then Value'Last < Natural'Last
               and then Pattern'First >= 1
               and then Value'First >= 1
               and then Pattern'First <= Pattern'Last + 1
               and then Value'First <= Value'Last + 1
   is
      Anchored : constant Boolean :=
        Pattern'Length > 0 and then Pattern (Pattern'First) = '^';
      Pat : constant String :=
        (if Anchored
         then Pattern (Pattern'First + 1 .. Pattern'Last) else Pattern);
   begin
      if Anchored then
         return Match_Here
           (Pat, Pat'First, Value, Value'First, Insensitive, Match_Depth_Limit);
      end if;
      for Start in 0 .. Value'Length loop
         if Match_Here
           (Pat, Pat'First, Value, Value'First + Start, Insensitive,
            Match_Depth_Limit)
         then
            return True;
         end if;
      end loop;
      return False;
   end Regex_Matches;

   --  ------------------------------------------------------------------
   --  Evaluation
   --  ------------------------------------------------------------------

   procedure Add_Violation
      (Target : in out Violation_Table;
       Item   : Validation.Violation)
   with Post => Target.Count >= Target.Count'Old
   is
   begin
      for I in 1 .. Target.Count loop
         if Target.List (I) = Item then
            return;
         end if;
      end loop;
      if Target.Count < Max_Violations then
         Target.Count := Target.Count + 1;
         Target.List (Target.Count) := Item;
      end if;
   end Add_Violation;

   procedure Note_Violation
      (Value     : Terms.Term;
       Shape     : Shapes.Shape;
       Focus     : Terms.Term;
       Component : Shapes.Constraint_Kind;
       Target    : in out Violation_Table;
       Emit      : Boolean;
       Passed    : Boolean;
       Ok        : in out Boolean)
   with Post => Target.Count >= Target.Count'Old
   is
   begin
      if not Passed then
         Ok := False;
         if Emit then
            Add_Violation
              (Target,
               (Focus_Node   => Focus,
                Value_Node   => Value,
                Path         => Shape.Path,
                Source_Shape => Shape.Node,
                Component    => Component));
         end if;
      end if;
   end Note_Violation;

   --  Boolean connectives: aggregated once per kind per value node.
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
   is
   begin
      for K in Shapes.Constraint_Kind loop
         pragma Loop_Invariant (Target.Count >= Target'Loop_Entry.Count);
         Check_Kind
           (K, Value, Shape, Focus, Graph, Shape_Set, Depth, Target, Emit,
            Ok);
      end loop;
   end Check_Connectives;

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
   is
   begin
      if K in Shapes.Not_Shape | Shapes.And_Shape
                    | Shapes.Or_Shape | Shapes.Xone_Shape
      then
         declare
            Members : Natural := 0;
            Passing : Natural := 0;
         begin
            for Position in 1 .. Shape.Constraint_Count loop
               pragma Loop_Invariant
                 (Members <= Position - 1
                  and then Passing <= Members
                  and then Target.Count >= Target'Loop_Entry.Count);
               if Shape.Constraints (Position).Kind = K then
                  Members := Members + 1;
                  declare
                     Member_Ok : Boolean;
                  begin
                     Conforms_To_Ref
                       (Value, Shape_Set,
                        Shape.Constraints (Position).Value, Graph, Depth,
                        Target, Member_Ok);
                     if Member_Ok then
                        Passing := Passing + 1;
                     end if;
                  end;
               end if;
            end loop;
            if Members > 0 then
               declare
                  Pass : constant Boolean :=
                    (case K is
                        when Shapes.Not_Shape  => Passing = 0,
                        when Shapes.And_Shape  => Passing = Members,
                        when Shapes.Or_Shape   => Passing > 0,
                        when others            => Passing = 1);
               begin
                  Note_Violation
                    (Value, Shape, Focus, K, Target, Emit, Pass, Ok);
               end;
            end if;
         end;
      end if;
   end Check_Kind;

   function Effective_Datatype (Value : Terms.Term) return String is
   begin
      if Terms.Kind_Of (Value) /= Terms.Literal then
         return "";
      end if;
      if Terms.Language_Of (Value)'Length > 0 then
         return Lang_String;
      end if;
      if Terms.Datatype_Of (Value)'Length = 0 then
         return Xsd_String;
      end if;
      return Terms.Datatype_Of (Value);
   end Effective_Datatype;

   --  Value-string of a node for pattern and length components: the
   --  lexical form of a literal, the IRI of an IRI; blank nodes have
   --  none.
   function Value_String (Value : Terms.Term) return String is
     (if Terms.Kind_Of (Value) = Terms.Literal
      then Terms.Lexical_Of (Value) else Terms.Name_Of (Value));

   procedure Conforms_To_Ref
      (Node : Terms.Term;
       Shape_Set : Shapes.Shape_Table;
       Ref_Node : Terms.Term;
       Graph : Data.Graph;
       Depth : Natural;
       Target : in out Violation_Table;
       Ok : out Boolean)
   is
      Ref : constant Natural := Shapes.Find (Shape_Set, Ref_Node);
   begin
      if Ref = 0 or else Depth >= Max_Depth then
         Ok := True;  -- unresolvable reference or depth exhaustion
      else
         Check_Node (Node, Ref, Graph, Shape_Set, Depth + 1, Target, False, Ok);
      end if;
   end Conforms_To_Ref;

   --  Pairwise comparison for sh:lessThan / sh:lessThanOrEquals.
   function Pair_Less (A, B : Terms.Term; Or_Equal : Boolean) return Boolean is
      An : constant Parsed_Number := Numeric_Of (A);
      Bn : constant Parsed_Number := Numeric_Of (B);
   begin
      if An.Valid and then Bn.Valid then
         declare
            R : constant Integer := Compare_Numbers (An, Bn);
         begin
            return (if Or_Equal then R <= 0 else R < 0);
         end;
      elsif not An.Valid
        and then not Bn.Valid
        and then Terms.Kind_Of (A) = Terms.Literal
        and then Terms.Kind_Of (B) = Terms.Literal
      then
         return Lex_Less (Terms.Lexical_Of (A), Terms.Lexical_Of (B), Or_Equal);
      else
         --  Mixed comparability: a numeric value against a non-numeric
         --  one never satisfies a less-than relation.
         return False;
      end if;
   end Pair_Less;

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
   is
      All_Ok : Boolean := True;
   begin
      Ok := True;
      for Position in 1 .. Shape.Constraint_Count loop
         pragma Loop_Invariant (Target.Count >= Target'Loop_Entry.Count);
         declare
            C : constant Shapes.Constraint := Shape.Constraints (Position);
         begin
            case C.Kind is

               when Shapes.Min_Count | Shapes.Max_Count
                  | Shapes.Unique_Lang
                  | Shapes.Qualified_Value_Shape
                  | Shapes.Qualified_Shapes_Disjoint
                  | Shapes.Qualified_Min_Count
                  | Shapes.Qualified_Max_Count
                  | Shapes.Equals_Param
                  | Shapes.Disjoint_Param
                  | Shapes.Less_Than
                  | Shapes.Less_Than_Or_Equals
                  | Shapes.Closed_Param
                  | Shapes.Ignored_Property =>
                  null;  -- focus-level components

               when Shapes.Has_Value_Param =>
                  if not Property_Context then
                     Note_Violation
                       (Value, Shape, Focus, Shapes.Has_Value_Param,
                        Target, Emit, Same (C.Value, Value), All_Ok);
                  end if;

               when Shapes.Datatype_Param =>
                  declare
                     Want : constant String :=
                       (if Terms.Name_Of (C.Value)'Length = 0
                        then Xsd_String else Terms.Name_Of (C.Value));
                  begin
                     Note_Violation
                       (Value, Shape, Focus, Shapes.Datatype_Param, Target,
                        Emit,
                        Effective_Datatype (Value) = Want
                          and then Terms.Kind_Of (Value) = Terms.Literal,
                        All_Ok);
                  end;

               when Shapes.Node_Kind_Param =>
                  declare
                     Want : constant String := Terms.Name_Of (C.Value);
                     Kind : constant Terms.Term_Kind := Terms.Kind_Of (Value);
                     Pass : constant Boolean :=
                       (if    Want = Sh_Iri        then Kind = Terms.Iri
                        elsif Want = Sh_Blank_Node then Kind = Terms.Blank_Node
                        elsif Want = Sh_Literal    then Kind = Terms.Literal
                        elsif Want = Sh_Bn_Or_Iri  then
                          Kind in Terms.Iri | Terms.Blank_Node
                        elsif Want = Sh_Bn_Or_Lit  then
                          Kind in Terms.Blank_Node | Terms.Literal
                        elsif Want = Sh_Iri_Or_Lit then
                          Kind in Terms.Iri | Terms.Literal
                        else True);
                  begin
                     Note_Violation
                       (Value, Shape, Focus, Shapes.Node_Kind_Param,
                        Target, Emit, Pass, All_Ok);
                  end;

               when Shapes.Class_Param =>
                  Note_Violation
                    (Value, Shape, Focus, Shapes.Class_Param, Target, Emit,
                     Terms.Kind_Of (Value) /= Terms.Literal
                       and then Is_Instance (Graph, Value, C.Value),
                     All_Ok);

               when Shapes.Min_Length | Shapes.Max_Length =>
                  if Terms.Kind_Of (Value) = Terms.Blank_Node then
                     Note_Violation
                       (Value, Shape, Focus, C.Kind, Target, Emit, False,
                        All_Ok);
                  else
                     declare
                        Len : constant Natural :=
                          Codepoints (Value_String (Value));
                     begin
                        if C.Kind = Shapes.Min_Length then
                           Note_Violation
                             (Value, Shape, Focus, Shapes.Min_Length, Target,
                              Emit, Len >= Param_Count (C.Value), All_Ok);
                        else
                           Note_Violation
                             (Value, Shape, Focus, Shapes.Max_Length, Target,
                              Emit, Len <= Param_Count (C.Value), All_Ok);
                        end if;
                     end;
                  end if;

               when Shapes.Pattern_Param =>
                  if Terms.Kind_Of (Value) /= Terms.Blank_Node then
                     declare
                        Pass : constant Boolean :=
                          Regex_Matches
                            (Terms.Lexical_Of (C.Value), Value_String (Value),
                             Contains (Terms.Lexical_Of (C.Extra), "i"));
                     begin
                        Note_Violation
                          (Value, Shape, Focus, Shapes.Pattern_Param,
                           Target, Emit, Pass, All_Ok);
                     end;
                  end if;

               when Shapes.Language_In =>
                  if Terms.Kind_Of (Value) = Terms.Literal
                    and then Terms.Language_Of (Value)'Length > 0
                  then
                     declare
                        Found : Boolean := False;
                     begin
                        for K in 1 .. Shape.Constraint_Count loop
                           if Shape.Constraints (K).Kind = Shapes.Language_In
                             and then Fold_Equal
                                        (Terms.Lexical_Of
                                           (Shape.Constraints (K).Value),
                                         Terms.Language_Of (Value))
                           then
                              Found := True;
                           end if;
                        end loop;
                        Note_Violation
                          (Value, Shape, Focus, Shapes.Language_In,
                           Target, Emit, Found, All_Ok);
                     end;
                  else
                     Note_Violation
                       (Value, Shape, Focus, Shapes.Language_In,
                        Target, Emit, False, All_Ok);
                  end if;

               when Shapes.In_Member =>
                  declare
                     Found : Boolean := False;
                  begin
                     for K in 1 .. Shape.Constraint_Count loop
                        if Shape.Constraints (K).Kind = Shapes.In_Member
                          and then Same (Shape.Constraints (K).Value, Value)
                        then
                           Found := True;
                        end if;
                     end loop;
                     Note_Violation
                       (Value, Shape, Focus, Shapes.In_Member,
                        Target, Emit, Found, All_Ok);
                  end;

               when Shapes.Min_Exclusive | Shapes.Max_Exclusive
                  | Shapes.Min_Inclusive | Shapes.Max_Inclusive =>
                  declare
                     Value_Num : constant Parsed_Number := Numeric_Of (Value);
                     Param_Num : constant Parsed_Number :=
                       Parse_Number (Terms.Lexical_Of (C.Value));
                  begin
                     if Value_Num.Valid and then Param_Num.Valid then
                        declare
                           R : constant Integer :=
                             Compare_Numbers (Value_Num, Param_Num);
                           Pass : constant Boolean :=
                             (case C.Kind is
                                 when Shapes.Min_Exclusive => R > 0,
                                 when Shapes.Max_Exclusive => R < 0,
                                 when Shapes.Min_Inclusive => R >= 0,
                                 when others               => R <= 0);
                        begin
                           Note_Violation
                             (Value, Shape, Focus, C.Kind, Target, Emit, Pass,
                              All_Ok);
                        end;
                     else
                        --  A value outside the numeric surface violates;
                        --  the Recommendation calls it a failure, the
                        --  suite records a result.
                        Note_Violation
                          (Value, Shape, Focus, C.Kind, Target, Emit, False,
                           All_Ok);
                     end if;
                  end;

                when Shapes.Node_Link =>
                   declare
                      Ref_Ok : Boolean;
                   begin
                      Conforms_To_Ref
                        (Value, Shape_Set, C.Value, Graph, Depth, Target,
                         Ref_Ok);
                      Note_Violation
                        (Value, Shape, Focus, Shapes.Node_Link, Target, Emit,
                         Ref_Ok, All_Ok);
                   end;

               when Shapes.Not_Shape | Shapes.And_Shape
                  | Shapes.Or_Shape | Shapes.Xone_Shape =>
                  null;  -- aggregated after the loop

               when Shapes.Property_Link =>
                  null;  -- focus-level
            end case;
         end;
      end loop;

      Check_Connectives
        (Value, Shape, Focus, Graph, Shape_Set, Depth, Target, Emit, All_Ok);

      Ok := All_Ok;
   end Check_Value_Constraints;

   procedure Check_Node
     (Node   : Terms.Term;
      Idx    : Positive;
      Graph  : Data.Graph;
      Shape_Set : Shapes.Shape_Table;
      Depth  : Natural;
      Target : in out Violation_Table;
      Emit   : Boolean;
      Ok     : out Boolean)
   is
      Shape : constant Shapes.Shape := Shape_Set.List (Idx);
      All_Ok : Boolean := True;
   begin
      Ok := True;
      if Depth >= Max_Depth then
         return;  -- deep shape references conform vacuously
      end if;

      if not Shape.Has_Path then
         Check_Value_Constraints
           (Node, Shape, Node, Graph, Shape_Set, Depth + 1,
            Property_Context => False,
            Target => Target, Emit => Emit, Ok => All_Ok);

         --  sh:closed: every predicate on the focus node must be a path
         --  of one of this shape's property shapes, an ignored property,
         --  or rdf:type.
         declare
            Has_Closed : Boolean := False;
         begin
            for Position in 1 .. Shape.Constraint_Count loop
               if Shape.Constraints (Position).Kind = Shapes.Closed_Param
                 and then Terms.Lexical_Of
                            (Shape.Constraints (Position).Value) = "true"
               then
                  Has_Closed := True;
               end if;
            end loop;
            if Has_Closed then
               for T in 1 .. Graph.Count loop
                  pragma Loop_Invariant (Target.Count >= Target'Loop_Entry.Count);
                  declare
                     Stmt : constant Data.Triple := Data.Element (Graph, T);
                  begin
                     if Same (Stmt.Subject, Node)
                       and then not Same (Stmt.Predicate, Rdf_Type_Term)
                     then
                        declare
                           Allowed : Boolean := False;
                        begin
                           for Position in 1 .. Shape.Constraint_Count loop
                              declare
                                 C : constant Shapes.Constraint :=
                                   Shape.Constraints (Position);
                                 Ref : Natural;
                              begin
                                 if C.Kind = Shapes.Ignored_Property
                                   and then Same (C.Value, Stmt.Predicate)
                                 then
                                    Allowed := True;
                                 elsif C.Kind = Shapes.Property_Link then
                                    Ref := Shapes.Find (Shape_Set, C.Value);
                                    if Ref > 0
                                      and then Shape_Set.List (Ref).Has_Path
                                      and then Same
                                                 (Shape_Set.List (Ref).Path,
                                                  Stmt.Predicate)
                                    then
                                       Allowed := True;
                                    end if;
                                 end if;
                              end;
                           end loop;
                           if not Allowed then
                              Note_Violation
                                (Stmt.Object, Shape, Node,
                                 Shapes.Closed_Param, Target, Emit, False,
                                 All_Ok);
                           end if;
                        end;
                     end if;
                  end;
               end loop;
            end if;
         end;

         --  sh:equals / sh:disjoint / sh:lessThan / sh:lessThanOrEquals
         --  at a node shape: the value-node set is the focus node itself,
         --  compared against the objects of the parameter predicate.
         for Position in 1 .. Shape.Constraint_Count loop
            pragma Loop_Invariant (Target.Count >= Target'Loop_Entry.Count);
            declare
               C : constant Shapes.Constraint := Shape.Constraints (Position);
            begin
               case C.Kind is
                  when Shapes.Equals_Param | Shapes.Disjoint_Param
                     | Shapes.Less_Than | Shapes.Less_Than_Or_Equals =>
                     declare
                        Other_Count : constant Natural :=
                          Value_Count (Graph, Node, C.Value);
                        Pass        : Boolean := True;
                     begin
                        case C.Kind is
                           when Shapes.Equals_Param =>
                              Pass := Other_Count = 1
                                and then Same
                                           (Nth_Object
                                              (Graph, Node, C.Value, 1),
                                            Node);
                           when Shapes.Disjoint_Param =>
                              for J in 1 .. Other_Count loop
                                 exit when not Pass;
                                 if Same
                                      (Nth_Object
                                         (Graph, Node, C.Value, J),
                                       Node)
                                 then
                                    Pass := False;
                                 end if;
                              end loop;
                           when others =>
                              declare
                                 Or_Equal : constant Boolean :=
                                   C.Kind = Shapes.Less_Than_Or_Equals;
                              begin
                                 for J in 1 .. Other_Count loop
                                    exit when not Pass;
                                    if not Pair_Less
                                              (Node,
                                               Nth_Object
                                                 (Graph, Node, C.Value, J),
                                               Or_Equal)
                                    then
                                       Pass := False;
                                    end if;
                                 end loop;
                              end;
                        end case;
                        Note_Violation
                          (Terms.Empty, Shape, Node, C.Kind, Target, Emit,
                           Pass, All_Ok);
                     end;
                  when others =>
                     null;
               end case;
            end;
         end loop;
      else
         Check_Property
           (Node, Idx, Graph, Shape_Set, Depth + 1, Target, Emit, All_Ok);
      end if;

      --  sh:property links: the focus node also conforms to each
      --  referenced property shape.
      for Position in 1 .. Shape.Constraint_Count loop
         pragma Loop_Invariant (Target.Count >= Target'Loop_Entry.Count);
         if Shape.Constraints (Position).Kind = Shapes.Property_Link then
            declare
               Ref : constant Natural :=
                 Shapes.Find (Shape_Set, Shape.Constraints (Position).Value);
               Sub_Ok : Boolean := True;
            begin
               if Ref > 0 then
                  Check_Property
                    (Node, Ref, Graph, Shape_Set, Depth + 1,
                     Target, Emit, Sub_Ok);
                  if not Sub_Ok then
                     All_Ok := False;
                  end if;
               end if;
            end;
         end if;
      end loop;

      Ok := All_Ok;
   end Check_Node;

   --  Qualified cardinality: how many value nodes conform to the
   --  referenced shape.
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
   is
      Has_Min, Has_Max : Boolean := False;
      Q_Min, Q_Max : Natural := 0;
      Ref_Node : Terms.Term := Terms.Empty;
   begin
      for Position in 1 .. Shape.Constraint_Count loop
         declare
            C : constant Shapes.Constraint := Shape.Constraints (Position);
         begin
            case C.Kind is
               when Shapes.Qualified_Value_Shape =>
                  Ref_Node := C.Value;
               when Shapes.Qualified_Min_Count =>
                  Has_Min := True;
                  Q_Min := Param_Count (C.Value);
               when Shapes.Qualified_Max_Count =>
                  Has_Max := True;
                  Q_Max := Param_Count (C.Value);
               when others =>
                  null;
            end case;
         end;
      end loop;
      if (Has_Min or Has_Max)
        and then not Terms.Is_Empty (Ref_Node)
      then
         declare
            Ref : constant Natural := Shapes.Find (Shape_Set, Ref_Node);
            Conforming : Natural := 0;
         begin
            if Ref > 0 then
               for I in 1 .. Count loop
                  pragma Loop_Invariant
                    (Conforming <= I - 1
                     and then Target.Count >= Target'Loop_Entry.Count);
                  declare
                     V_Ok : Boolean := True;
                  begin
                     Check_Node
                       (Nth_Object (Graph, Focus, Shape.Path, I), Ref,
                        Graph, Shape_Set, Depth + 1, Target, False, V_Ok);
                     if V_Ok then
                        Conforming := Conforming + 1;
                     end if;
                  end;
               end loop;
            end if;
            if Has_Min then
               Note_Violation
                 (Terms.Empty, Shape, Focus, Shapes.Qualified_Min_Count,
                  Target, Emit, Conforming >= Q_Min, Ok);
            end if;
            if Has_Max then
               Note_Violation
                 (Terms.Empty, Shape, Focus, Shapes.Qualified_Max_Count,
                  Target, Emit, Conforming <= Q_Max, Ok);
            end if;
         end;
      end if;

      --  sh:qualifiedValueShapesDisjoint: sibling qualified shapes on
      --  the same path must not share conforming value nodes.
      declare
         Disjoint : Boolean := False;
      begin
         for Position in 1 .. Shape.Constraint_Count loop
            if Shape.Constraints (Position).Kind
                 = Shapes.Qualified_Shapes_Disjoint
              and then Terms.Lexical_Of
                         (Shape.Constraints (Position).Value) = "true"
            then
               Disjoint := True;
            end if;
         end loop;
         if Disjoint
           and then not Terms.Is_Empty (Ref_Node)
           and then Shape.Has_Path
         then
            declare
               Ref : constant Natural := Shapes.Find (Shape_Set, Ref_Node);
            begin
               if Ref > 0 then
                  for K in 1 .. Shape_Set.Count loop
                     pragma Loop_Invariant
                       (Target.Count >= Target'Loop_Entry.Count);
                     declare
                        Sibling      : constant Shapes.Shape :=
                          Shape_Set.List (K);
                        Sib_Ref      : Terms.Term := Terms.Empty;
                        Sib_Disjoint : Boolean := False;
                     begin
                        if not Same (Sibling.Node, Shape.Node)
                          and then Sibling.Has_Path
                          and then Same (Sibling.Path, Shape.Path)
                        then
                           for Position in 1 .. Sibling.Constraint_Count
                           loop
                              declare
                                 C : constant Shapes.Constraint :=
                                   Sibling.Constraints (Position);
                              begin
                                 case C.Kind is
                                    when Shapes.Qualified_Value_Shape =>
                                       Sib_Ref := C.Value;
                                    when Shapes.Qualified_Shapes_Disjoint =>
                                       if Terms.Lexical_Of (C.Value)
                                            = "true"
                                       then
                                          Sib_Disjoint := True;
                                       end if;
                                    when others =>
                                       null;
                                 end case;
                              end;
                           end loop;
                           if Sib_Disjoint
                             and then not Terms.Is_Empty (Sib_Ref)
                           then
                              declare
                                 Sib : constant Natural :=
                                   Shapes.Find (Shape_Set, Sib_Ref);
                              begin
                                 if Sib > 0 then
                                    for I in 1 .. Count loop
                                       pragma Loop_Invariant
                                         (Target.Count
                                          >= Target'Loop_Entry.Count);
                                       declare
                                          V    : constant Terms.Term :=
                                            Nth_Object
                                              (Graph, Focus,
                                               Shape.Path, I);
                                          A_Ok : Boolean := True;
                                          B_Ok : Boolean := True;
                                       begin
                                          Check_Node
                                            (V, Ref, Graph, Shape_Set,
                                             Depth + 1, Target, False,
                                             A_Ok);
                                          Check_Node
                                            (V, Sib, Graph, Shape_Set,
                                             Depth + 1, Target, False,
                                             B_Ok);
                                          if A_Ok and then B_Ok then
                                             Note_Violation
                                               (Terms.Empty, Shape, Focus,
                                                Shapes.
                                                  Qualified_Shapes_Disjoint,
                                                Target, Emit, False, Ok);
                                          end if;
                                       end;
                                    end loop;
                                 end if;
                              end;
                           end if;
                        end if;
                     end;
                  end loop;
               end if;
            end;
         end if;
      end;
   end Check_Qualified;

   procedure Check_Property
      (Focus  : Terms.Term;
       Idx    : Positive;
       Graph  : Data.Graph;
       Shape_Set : Shapes.Shape_Table;
       Depth  : Natural;
       Target : in out Violation_Table;
       Emit   : Boolean;
       Ok     : out Boolean)
   is
      Shape  : constant Shapes.Shape := Shape_Set.List (Idx);
      Count  : constant Natural := Value_Count (Graph, Focus, Shape.Path);
      All_Ok : Boolean := True;
   begin
      Ok := True;
      if Depth >= Max_Depth then
         return;
      end if;

      for Position in 1 .. Shape.Constraint_Count loop
         pragma Loop_Invariant (Target.Count >= Target'Loop_Entry.Count);
         declare
            C : constant Shapes.Constraint := Shape.Constraints (Position);
         begin
            case C.Kind is
               when Shapes.Min_Count =>
                  Note_Violation
                    (Terms.Empty, Shape, Focus, Shapes.Min_Count, Target,
                     Emit, Count >= Param_Count (C.Value), All_Ok);
               when Shapes.Max_Count =>
                  Note_Violation
                    (Terms.Empty, Shape, Focus, Shapes.Max_Count, Target,
                     Emit, Count <= Param_Count (C.Value), All_Ok);
               when others =>
                  null;
            end case;
         end;
      end loop;

      --  sh:uniqueLang: no two value nodes share a language tag.
      declare
         Has_Unique : Boolean := False;
      begin
         for Position in 1 .. Shape.Constraint_Count loop
            if Shape.Constraints (Position).Kind = Shapes.Unique_Lang
              and then Terms.Lexical_Of
                         (Shape.Constraints (Position).Value) = "true"
            then
               Has_Unique := True;
            end if;
         end loop;
         if Has_Unique and then Count > 1 then
            for I in 1 .. Count - 1 loop
               pragma Loop_Invariant (Target.Count >= Target'Loop_Entry.Count);
               for J in I + 1 .. Count loop
                  pragma Loop_Invariant
                    (Target.Count >= Target'Loop_Entry.Count);
                  declare
                     A : constant Terms.Term :=
                       Nth_Object (Graph, Focus, Shape.Path, I);
                     B : constant Terms.Term :=
                       Nth_Object (Graph, Focus, Shape.Path, J);
                  begin
                     if Terms.Kind_Of (A) = Terms.Literal
                       and then Terms.Kind_Of (B) = Terms.Literal
                       and then Terms.Language_Of (A)'Length > 0
                       and then Fold_Equal (Terms.Language_Of (A),
                                            Terms.Language_Of (B))
                     then
                        Note_Violation
                          (B, Shape, Focus, Shapes.Unique_Lang, Target,
                           Emit, False, All_Ok);
                     end if;
                  end;
               end loop;
            end loop;
         end if;
      end;

      --  sh:hasValue: at least one value node equals the given value.
      for Position in 1 .. Shape.Constraint_Count loop
         pragma Loop_Invariant (Target.Count >= Target'Loop_Entry.Count);
         declare
            C : constant Shapes.Constraint := Shape.Constraints (Position);
            Found : Boolean := False;
         begin
            if C.Kind = Shapes.Has_Value_Param then
               for I in 1 .. Count loop
                  if Same (Nth_Object (Graph, Focus, Shape.Path, I), C.Value)
                  then
                     Found := True;
                  end if;
               end loop;
               Note_Violation
                 (Terms.Empty, Shape, Focus, Shapes.Has_Value_Param, Target,
                  Emit, Found, All_Ok);
            end if;
         end;
      end loop;

      Check_Qualified
        (Shape, Focus, Graph, Shape_Set, Depth, Count, Target, Emit, All_Ok);

      --  sh:equals / sh:disjoint / sh:lessThan / sh:lessThanOrEquals.
      for Position in 1 .. Shape.Constraint_Count loop
         declare
            C : constant Shapes.Constraint := Shape.Constraints (Position);
         begin
            case C.Kind is
               when Shapes.Equals_Param | Shapes.Disjoint_Param
                  | Shapes.Less_Than | Shapes.Less_Than_Or_Equals =>
                  declare
                     Other : constant Terms.Term := C.Value;
                     Other_Count : constant Natural :=
                       Value_Count (Graph, Focus, Other);
                     Pass : Boolean := True;
                  begin
                     case C.Kind is
                        when Shapes.Equals_Param =>
                           Pass := Other_Count = Count;
                           if Pass then
                              for I in 1 .. Count loop
                                 exit when not Pass;
                                 Pass := Object_Matches
                                   (Graph, Focus, Other,
                                    Nth_Object (Graph, Focus, Shape.Path, I));
                              end loop;
                           end if;
                        when Shapes.Disjoint_Param =>
                           for I in 1 .. Count loop
                              exit when not Pass;
                              for J in 1 .. Other_Count loop
                                 if Same
                                      (Nth_Object
                                         (Graph, Focus, Shape.Path, I),
                                       Nth_Object (Graph, Focus, Other, J))
                                 then
                                    Pass := False;
                                 end if;
                              end loop;
                           end loop;
                        when others =>
                           declare
                              Or_Equal : constant Boolean :=
                                C.Kind = Shapes.Less_Than_Or_Equals;
                           begin
                              for I in 1 .. Count loop
                                 exit when not Pass;
                                 for J in 1 .. Other_Count loop
                                    if not Pair_Less
                                         (Nth_Object
                                            (Graph, Focus, Shape.Path, I),
                                          Nth_Object (Graph, Focus, Other, J),
                                          Or_Equal)
                                    then
                                       Pass := False;
                                    end if;
                                 end loop;
                              end loop;
                           end;
                     end case;
                     Note_Violation
                       (Terms.Empty, Shape, Focus, C.Kind, Target, Emit,
                        Pass, All_Ok);
                  end;
               when others =>
                  null;
            end case;
         end;
      end loop;

      --  Value-level components on every value node.
      for I in 1 .. Count loop
         pragma Loop_Invariant (Target.Count >= Target'Loop_Entry.Count);
         declare
            Value : constant Terms.Term :=
              Nth_Object (Graph, Focus, Shape.Path, I);
            Value_Ok : Boolean := True;
         begin
            Check_Value_Constraints
              (Value, Shape, Focus, Graph, Shape_Set, Depth + 1,
               Property_Context => True,
               Target => Target, Emit => Emit, Ok => Value_Ok);
            if not Value_Ok then
               All_Ok := False;
            end if;
         end;
      end loop;

      --  Nested property shapes.
      for Position in 1 .. Shape.Constraint_Count loop
         if Shape.Constraints (Position).Kind = Shapes.Property_Link then
            declare
               Ref : constant Natural :=
                 Shapes.Find (Shape_Set, Shape.Constraints (Position).Value);
               Sub_Ok : Boolean := True;
            begin
               if Ref > 0 then
                  --  Nested property shapes constrain the values of
                  --  this shape's path, not the focus node itself.
                  for I in 1 .. Count loop
                     pragma Loop_Invariant
                       (Target.Count >= Target'Loop_Entry.Count);
                     declare
                        V : constant Terms.Term :=
                          Nth_Object (Graph, Focus, Shape.Path, I);
                     begin
                        Sub_Ok := True;
                        Check_Property
                          (V, Ref, Graph, Shape_Set, Depth + 1,
                           Target, Emit, Sub_Ok);
                        if not Sub_Ok then
                           All_Ok := False;
                        end if;
                     end;
                  end loop;
               end if;
            end;
         end if;
      end loop;

      Ok := All_Ok;
   end Check_Property;

   procedure Validate
      (Shape_Set : Shapes.Shape_Table;
       Graph     : Data.Graph;
       Into      : in out Violation_Table)
   is
      Before : constant Natural := Into.Count;

      procedure Check_Focus
        (Focus : Terms.Term; Idx : Positive) with
        Pre  => Idx <= Shape_Set.Count,
        Post => Into.Count >= Into.Count'Old
      is
         Ok    : Boolean := True;
      begin
         if Shape_Set.List (Idx).Has_Path then
            Check_Property
              (Focus, Idx, Graph, Shape_Set, 0, Into, True, Ok);
         else
            Check_Node
              (Focus, Idx, Graph, Shape_Set, 0, Into, True, Ok);
         end if;
      end Check_Focus;
   begin
      for Idx in 1 .. Shape_Set.Count loop
         pragma Loop_Invariant (Into.Count >= Before);
         declare
            Shape : constant Shapes.Shape := Shape_Set.List (Idx);
         begin
            if Shape.Deactivated then
               --  sh:deactivated true: the shape validates nothing.
               null;
            else
            for T in 1 .. Shape.Target_Count loop
               pragma Loop_Invariant (Into.Count >= Before);
               declare
                  Tg : constant Shapes.Target := Shape.Targets (T);
               begin
                  case Tg.Kind is
                     when Shapes.Target_Node =>
                        Check_Focus (Tg.Value, Idx);
                     when Shapes.Target_Class =>
                         for I in 1 .. Graph.Count loop
                            pragma Loop_Invariant (Into.Count >= Before);
                            declare
                              Stmt : constant Data.Triple :=
                                Data.Element (Graph, I);
                           begin
                              if Same (Stmt.Predicate, Rdf_Type_Term)
                                and then (Same (Stmt.Object, Tg.Value)
                                            or else Subclass_Reaches
                                                     (Graph, Stmt.Object,
                                                      Tg.Value, Max_Depth))
                              then
                                 Check_Focus (Stmt.Subject, Idx);
                              end if;
                           end;
                        end loop;
                     when Shapes.Target_Subjects_Of =>
                         for I in 1 .. Graph.Count loop
                            pragma Loop_Invariant (Into.Count >= Before);
                            declare
                              Stmt : constant Data.Triple :=
                                Data.Element (Graph, I);
                           begin
                              if Same (Stmt.Predicate, Tg.Value) then
                                 Check_Focus (Stmt.Subject, Idx);
                              end if;
                           end;
                        end loop;
                     when Shapes.Target_Objects_Of =>
                         for I in 1 .. Graph.Count loop
                            pragma Loop_Invariant (Into.Count >= Before);
                            declare
                              Stmt : constant Data.Triple :=
                                Data.Element (Graph, I);
                           begin
                              if Same (Stmt.Predicate, Tg.Value) then
                                 Check_Focus (Stmt.Object, Idx);
                              end if;
                           end;
                        end loop;
                  end case;
               end;
            end loop;

               --  Implicit class targets: a node shape that is also an
               --  rdfs:Class targets its instances in the data graph,
               --  reachable through rdfs:subClassOf.
               if Shape.Target_Count = 0
                 and then not Shape.Has_Path
                 and then Terms.Kind_Of (Shape.Node) = Terms.Iri
               then
                  declare
                     Is_Class : Boolean := False;
                  begin
                     for I in 1 .. Graph.Count loop
                        pragma Loop_Invariant (Into.Count >= Before);
                        declare
                           Stmt : constant Data.Triple :=
                             Data.Element (Graph, I);
                        begin
                           if Same (Stmt.Subject, Shape.Node)
                             and then Same (Stmt.Predicate, Rdf_Type_Term)
                             and then Same (Stmt.Object, Rdfs_Class_Term)
                           then
                              Is_Class := True;
                           end if;
                        end;
                     end loop;
                     if Is_Class then
                        for I in 1 .. Graph.Count loop
                           pragma Loop_Invariant (Into.Count >= Before);
                           declare
                              Stmt : constant Data.Triple :=
                                Data.Element (Graph, I);
                           begin
                              if Same (Stmt.Predicate, Rdf_Type_Term)
                                and then (Same (Stmt.Object, Shape.Node)
                                  or else Subclass_Reaches
                                           (Graph, Stmt.Object,
                                            Shape.Node, Max_Depth))
                              then
                                 Check_Focus (Stmt.Subject, Idx);
                              end if;
                           end;
                        end loop;
                     end if;
                  end;
               end if;
            end if;
         end;
      end loop;
   end Validate;

end SHACL_Ada.Eval;
