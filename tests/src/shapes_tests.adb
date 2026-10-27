--  SPDX-License-Identifier: Apache-2.0
--
--  Shapes-graph extraction tests: one embedded Turtle document, asserted
--  through the pure core's model.

with Ada.Command_Line;
with Ada.Text_IO;

with Flyology_RDF.Datasets;

with SHACL_Ada.Rdf;
with SHACL_Ada.Shapes;
with SHACL_Ada.Terms;

procedure Shapes_Tests is

   use type SHACL_Ada.Shapes.Constraint_Kind;
   use type SHACL_Ada.Shapes.Path_Kind;
   use type SHACL_Ada.Shapes.Target_Kind;
   use type SHACL_Ada.Shapes.Severity_Kind;

   Failures : Natural := 0;

   --  A Shape_Table is a few megabytes; it lives on the heap, never on a
   --  default-size stack.
   type Shape_Table_Ref is access all SHACL_Ada.Shapes.Shape_Table;

   procedure Check (Condition : Boolean; Label : String) is
   begin
      if Condition then
         Ada.Text_IO.Put_Line ("PASS " & Label);
      else
         Ada.Text_IO.Put_Line ("FAIL " & Label);
         Failures := Failures + 1;
      end if;
   end Check;

   function Count_Kind
     (Shape : SHACL_Ada.Shapes.Shape;
      Kind  : SHACL_Ada.Shapes.Constraint_Kind) return Natural
   is
      Result : Natural := 0;
   begin
      for Position in 1 .. Shape.Constraint_Count loop
         if Shape.Constraints (Position).Kind = Kind then
            Result := Result + 1;
         end if;
      end loop;
      return Result;
   end Count_Kind;

   function First_Value
     (Shape : SHACL_Ada.Shapes.Shape;
      Kind  : SHACL_Ada.Shapes.Constraint_Kind) return SHACL_Ada.Terms.Term
   is
   begin
      for Position in 1 .. Shape.Constraint_Count loop
         if Shape.Constraints (Position).Kind = Kind then
            return Shape.Constraints (Position).Value;
         end if;
      end loop;
      return SHACL_Ada.Terms.Empty;
   end First_Value;

   function Has_In_Member (Shape : SHACL_Ada.Shapes.Shape; Lexical : String)
                           return Boolean
   is
   begin
      for Position in 1 .. Shape.Constraint_Count loop
         if Shape.Constraints (Position).Kind = SHACL_Ada.Shapes.In_Member
           and then SHACL_Ada.Terms.Lexical_Of
                      (Shape.Constraints (Position).Value) = Lexical
         then
            return True;
         end if;
      end loop;
      return False;
   end Has_In_Member;

    Document : constant String :=
      "@prefix sh: <http://www.w3.org/ns/shacl#> ." & ASCII.LF &
      "@prefix ex: <http://example.org/> ." & ASCII.LF &
      "@prefix xsd: <http://www.w3.org/2001/XMLSchema#> ." & ASCII.LF &
      "ex:PersonShape a sh:NodeShape ;" & ASCII.LF &
      "  sh:targetClass ex:Person ;" & ASCII.LF &
      "  sh:property ex:NameProperty ." & ASCII.LF &
      "ex:NameProperty a sh:PropertyShape ;" & ASCII.LF &
      "  sh:path ex:name ;" & ASCII.LF &
      "  sh:minCount 1 ;" & ASCII.LF &
      "  sh:maxCount 1 ;" & ASCII.LF &
      "  sh:datatype xsd:string ;" & ASCII.LF &
      "  sh:in ( 1 2 3 ) ;" & ASCII.LF &
      "  sh:languageIn ( ""en"" ) ." & ASCII.LF &
      "ex:FriendShape a sh:PropertyShape ;" & ASCII.LF &
      "  sh:path ( ex:knows [ sh:inversePath ex:knows ] ) ;" & ASCII.LF &
      "  sh:minCount 1 ." & ASCII.LF &
      "ex:AltShape a sh:PropertyShape ;" & ASCII.LF &
      "  sh:path [ sh:alternativePath ( ex:p ex:q ex:r ) ] ;" & ASCII.LF &
      "  sh:minCount 1 ." & ASCII.LF &
      "ex:MoreShape a sh:PropertyShape ;" & ASCII.LF &
      "  sh:path [ sh:zeroOrMorePath ex:child ] ;" & ASCII.LF &
      "  sh:minCount 1 ." & ASCII.LF &
      "ex:OneShape a sh:PropertyShape ;" & ASCII.LF &
      "  sh:path [ sh:oneOrMorePath ex:child ] ;" & ASCII.LF &
      "  sh:minCount 1 ." & ASCII.LF &
      "ex:MaybeShape a sh:PropertyShape ;" & ASCII.LF &
      "  sh:path [ sh:zeroOrOnePath ex:child ] ;" & ASCII.LF &
      "  sh:minCount 1 ." & ASCII.LF;

   --  Report surface: sh:severity and sh:message extraction.
   Report_Document : constant String :=
     "@prefix sh: <http://www.w3.org/ns/shacl#> ." & ASCII.LF &
     "@prefix ex: <http://example.org/> ." & ASCII.LF &
     "ex:WarnShape a sh:PropertyShape ;" & ASCII.LF &
     "  sh:path ex:name ;" & ASCII.LF &
     "  sh:minCount 1 ;" & ASCII.LF &
     "  sh:severity sh:Warning ;" & ASCII.LF &
     "  sh:message ""Be careful""@en ." & ASCII.LF &
     "ex:PlainShape a sh:PropertyShape ;" & ASCII.LF &
     "  sh:path ex:age ;" & ASCII.LF &
     "  sh:minCount 1 ;" & ASCII.LF &
     "  sh:message ""plain note"" ." & ASCII.LF &
     "ex:MultiShape a sh:NodeShape ;" & ASCII.LF &
     "  sh:message ""hello""@en ;" & ASCII.LF &
     "  sh:message ""bonjour""@fr ;" & ASCII.LF &
     "  sh:message ""hello again""@en ." & ASCII.LF &
     "ex:BareShape a sh:NodeShape ." & ASCII.LF;

   Bad_Severity_Document : constant String :=
     "@prefix sh: <http://www.w3.org/ns/shacl#> ." & ASCII.LF &
     "@prefix ex: <http://example.org/> ." & ASCII.LF &
     "ex:BadShape a sh:NodeShape ;" & ASCII.LF &
     "  sh:severity ex:Bogus ." & ASCII.LF;

   Non_Literal_Message_Document : constant String :=
     "@prefix sh: <http://www.w3.org/ns/shacl#> ." & ASCII.LF &
     "@prefix ex: <http://example.org/> ." & ASCII.LF &
     "ex:BadShape a sh:NodeShape ;" & ASCII.LF &
     "  sh:message ex:Bogus ." & ASCII.LF;

   Too_Many_Messages_Document : constant String :=
     "@prefix sh: <http://www.w3.org/ns/shacl#> ." & ASCII.LF &
     "@prefix ex: <http://example.org/> ." & ASCII.LF &
     "ex:ChattyShape a sh:NodeShape ;" & ASCII.LF &
     "  sh:message ""one""@en ;" & ASCII.LF &
     "  sh:message ""un""@fr ;" & ASCII.LF &
     "  sh:message ""two""@de ;" & ASCII.LF &
     "  sh:message ""uno""@es ;" & ASCII.LF &
     "  sh:message ""uno-it""@it ." & ASCII.LF;

   procedure Check_Rejected (Document : String; Label : String) is
      Graph : Flyology_RDF.Datasets.Dataset;
      Ok    : Boolean;
      Table : constant Shape_Table_Ref :=
        new SHACL_Ada.Shapes.Shape_Table;
   begin
      SHACL_Ada.Rdf.Load_Turtle (Document, "", Graph, Ok);
      if not Ok then
         Check (False, Label & " parses");
         return;
      end if;
      begin
         SHACL_Ada.Rdf.Extract_Shapes (Graph, Table.all);
      exception
         when SHACL_Ada.Rdf.Boundary_Error =>
            Check (True, Label & " rejected");
            return;
      end;
      Check (False, Label & " rejected");
   end Check_Rejected;

begin
   declare
      Graph : Flyology_RDF.Datasets.Dataset;
      Ok    : Boolean;
      Table : constant Shape_Table_Ref :=
        new SHACL_Ada.Shapes.Shape_Table;
      Person : Natural;
      Name   : Natural;
   begin
      SHACL_Ada.Rdf.Load_Turtle (Document, "", Graph, Ok);
      Check (Ok, "turtle document parses");
      SHACL_Ada.Rdf.Extract_Shapes (Graph, Table.all);
      Check (Table.all.Count = 7, "seven shapes extracted");

      Person := SHACL_Ada.Shapes.Find
        (Table.all, SHACL_Ada.Terms.Make_Iri ("http://example.org/PersonShape"));
      Name := SHACL_Ada.Shapes.Find
        (Table.all, SHACL_Ada.Terms.Make_Iri ("http://example.org/NameProperty"));
      Check (Person > 0, "node shape found by node IRI");
      Check (Name > 0, "property shape found by node IRI");

      if Person > 0 then
         declare
            S : SHACL_Ada.Shapes.Shape renames Table.List (Person);
         begin
            Check (not S.Is_Property_Shape, "PersonShape is a node shape");
            Check (S.Target_Count = 1, "PersonShape has one target");
            Check (S.Targets (1).Kind = SHACL_Ada.Shapes.Target_Class,
                   "target kind is targetClass");
            Check (SHACL_Ada.Terms.Name_Of (S.Targets (1).Value)
                     = "http://example.org/Person",
                   "target class is ex:Person");
            Check (S.Constraint_Count = 1, "PersonShape has one constraint");
            Check (S.Constraints (1).Kind = SHACL_Ada.Shapes.Property_Link,
                   "constraint kind is sh:property");
            Check (SHACL_Ada.Terms.Name_Of (S.Constraints (1).Value)
                     = "http://example.org/NameProperty",
                   "property link is ex:NameProperty");
         end;
      end if;

      if Name > 0 then
         declare
            S : SHACL_Ada.Shapes.Shape renames Table.List (Name);
         begin
             Check (S.Is_Property_Shape, "NameProperty is a property shape");
             Check (S.Has_Path, "NameProperty has sh:path");
             Check (S.Path_Root > 0, "NameProperty has a path root");
             if S.Path_Root > 0 then
                declare
                   Root : constant SHACL_Ada.Shapes.Path_Node :=
                     Table.Paths (S.Path_Root);
                begin
                   Check (Root.Kind = SHACL_Ada.Shapes.Path_Predicate,
                          "path is a predicate path");
                   Check (SHACL_Ada.Terms.Name_Of (Root.Pred)
                            = "http://example.org/name",
                          "path is ex:name");
                end;
             end if;
            Check (Count_Kind (S, SHACL_Ada.Shapes.Min_Count) = 1,
                   "sh:minCount present");
            Check (Count_Kind (S, SHACL_Ada.Shapes.Max_Count) = 1,
                   "sh:maxCount present");
            Check (Count_Kind (S, SHACL_Ada.Shapes.Datatype_Param) = 1,
                   "sh:datatype present");
            Check (SHACL_Ada.Terms.Name_Of
                     (First_Value (S, SHACL_Ada.Shapes.Datatype_Param))
                     = "http://www.w3.org/2001/XMLSchema#string",
                   "datatype is xsd:string");
            Check (Count_Kind (S, SHACL_Ada.Shapes.In_Member) = 3,
                   "sh:in resolved to three members");
            Check (Has_In_Member (S, "3"), "sh:in member 3 present");
            Check (Count_Kind (S, SHACL_Ada.Shapes.Language_In) = 1,
                   "sh:languageIn resolved to one member");
             Check (SHACL_Ada.Terms.Lexical_Of
                      (First_Value (S, SHACL_Ada.Shapes.Language_In)) = "en",
                    "languageIn member is en");
          end;
       end if;

      --  Compound path extraction: sequence (predicate, inverse), a
      --  three-way alternative, and the three cardinality forms.
      declare
         Found : Natural;
      begin
         Found := SHACL_Ada.Shapes.Find
           (Table.all,
            SHACL_Ada.Terms.Make_Iri ("http://example.org/FriendShape"));
         Check (Found > 0, "FriendShape found");
         if Found > 0 then
            declare
               S    : SHACL_Ada.Shapes.Shape renames Table.List (Found);
               Root : constant SHACL_Ada.Shapes.Path_Node :=
                 Table.Paths (S.Path_Root);
            begin
               Check (Root.Kind = SHACL_Ada.Shapes.Path_Sequence,
                      "FriendShape root is a sequence");
               if Root.Kind = SHACL_Ada.Shapes.Path_Sequence then
                  Check
                    (Table.Paths (Root.Left).Kind
                       = SHACL_Ada.Shapes.Path_Predicate
                     and then SHACL_Ada.Terms.Name_Of
                                (Table.Paths (Root.Left).Pred)
                       = "http://example.org/knows",
                     "sequence head is ex:knows");
                  Check
                    (Table.Paths (Root.Right).Kind
                       = SHACL_Ada.Shapes.Path_Inverse,
                     "sequence tail is an inverse");
                  if Table.Paths (Root.Right).Kind
                       = SHACL_Ada.Shapes.Path_Inverse
                  then
                     Check
                       (Table.Paths (Table.Paths (Root.Right).Left).Kind
                          = SHACL_Ada.Shapes.Path_Predicate
                        and then SHACL_Ada.Terms.Name_Of
                                   (Table.Paths
                                      (Table.Paths (Root.Right).Left).Pred)
                             = "http://example.org/knows",
                         "inverse child is ex:knows");
                  end if;
               end if;
            end;
         end if;

         Found := SHACL_Ada.Shapes.Find
           (Table.all,
            SHACL_Ada.Terms.Make_Iri ("http://example.org/AltShape"));
         Check (Found > 0, "AltShape found");
         if Found > 0 then
            declare
               S    : SHACL_Ada.Shapes.Shape renames Table.List (Found);
               Root : constant SHACL_Ada.Shapes.Path_Node :=
                 Table.Paths (S.Path_Root);
               Mid  : constant SHACL_Ada.Shapes.Path_Node :=
                 Table.Paths (Root.Right);
            begin
               Check (Root.Kind = SHACL_Ada.Shapes.Path_Alternative,
                      "AltShape root is an alternative");
               Check (SHACL_Ada.Terms.Name_Of (Table.Paths (Root.Left).Pred)
                        = "http://example.org/p",
                      "alternative head is ex:p");
               Check (Mid.Kind = SHACL_Ada.Shapes.Path_Alternative,
                      "alternative tail is nested");
               Check (SHACL_Ada.Terms.Name_Of (Table.Paths (Mid.Left).Pred)
                        = "http://example.org/q",
                      "nested alternative head is ex:q");
               Check (SHACL_Ada.Terms.Name_Of (Table.Paths (Mid.Right).Pred)
                        = "http://example.org/r",
                      "nested alternative tail is ex:r");
            end;
         end if;

         declare
            procedure Check_Cardinality
              (Node_Name : String;
               Expect    : SHACL_Ada.Shapes.Path_Kind;
               Label     : String)
            is
               Found : constant Natural := SHACL_Ada.Shapes.Find
                 (Table.all, SHACL_Ada.Terms.Make_Iri (Node_Name));
            begin
               Check (Found > 0, Label & " found");
               if Found > 0 then
                  declare
                     S    : SHACL_Ada.Shapes.Shape renames Table.List (Found);
                     Root : constant SHACL_Ada.Shapes.Path_Node :=
                       Table.Paths (S.Path_Root);
                  begin
                     Check (Root.Kind = Expect, Label & " root kind");
                     if Root.Kind = Expect then
                        Check
                          (Table.Paths (Root.Left).Kind
                             = SHACL_Ada.Shapes.Path_Predicate
                           and then SHACL_Ada.Terms.Name_Of
                                      (Table.Paths (Root.Left).Pred)
                             = "http://example.org/child",
                           Label & " child is ex:child");
                     end if;
                  end;
               end if;
            end Check_Cardinality;
         begin
            Check_Cardinality
              ("http://example.org/MoreShape",
               SHACL_Ada.Shapes.Path_Zero_Or_More, "zeroOrMore");
            Check_Cardinality
              ("http://example.org/OneShape",
               SHACL_Ada.Shapes.Path_One_Or_More, "oneOrMore");
            Check_Cardinality
              ("http://example.org/MaybeShape",
               SHACL_Ada.Shapes.Path_Zero_Or_One, "zeroOrOne");
          end;
       end;
     end;

   --  Report surface: severity defaults to Violation, sh:severity and
   --  sh:message land on the shape, distinct languages accumulate,
   --  first per language wins, malformed values fail closed.
   declare
      Graph : Flyology_RDF.Datasets.Dataset;
      Ok    : Boolean;
      Table : constant Shape_Table_Ref :=
        new SHACL_Ada.Shapes.Shape_Table;

      function Shape_At (Name : String) return Natural is
      begin
         return SHACL_Ada.Shapes.Find
           (Table.all, SHACL_Ada.Terms.Make_Iri (Name));
      end Shape_At;
   begin
      SHACL_Ada.Rdf.Load_Turtle (Report_Document, "", Graph, Ok);
      Check (Ok, "report document parses");
      SHACL_Ada.Rdf.Extract_Shapes (Graph, Table.all);
      Check (Table.all.Count = 4, "four report shapes extracted");

      declare
         W : Natural := Shape_At ("http://example.org/WarnShape");
      begin
         Check (W > 0, "WarnShape found");
         if W > 0 then
            declare
               S : SHACL_Ada.Shapes.Shape renames Table.List (W);
            begin
               Check (S.Severity = SHACL_Ada.Shapes.Severity_Warning,
                      "sh:severity Warning stored");
               Check (S.Message_Count = 1, "one sh:message stored");
               if S.Message_Count = 1 then
                  Check (SHACL_Ada.Terms.Lexical_Of (S.Messages (1))
                           = "Be careful",
                         "message lexical kept");
                  Check (SHACL_Ada.Terms.Language_Of (S.Messages (1))
                           = "en",
                         "message language kept");
               end if;
            end;
         end if;
      end;

      declare
         P : Natural := Shape_At ("http://example.org/PlainShape");
      begin
         Check (P > 0, "PlainShape found");
         if P > 0 then
            declare
               S : SHACL_Ada.Shapes.Shape renames Table.List (P);
            begin
               Check (S.Severity = SHACL_Ada.Shapes.Severity_Violation,
                      "missing severity defaults to Violation");
               Check (S.Message_Count = 1, "plain message stored");
               if S.Message_Count = 1 then
                  Check (SHACL_Ada.Terms.Lexical_Of (S.Messages (1))
                           = "plain note",
                         "plain lexical kept");
                  Check (SHACL_Ada.Terms.Language_Of (S.Messages (1))
                           = "",
                         "plain message has no language");
               end if;
            end;
         end if;
      end;

      declare
         M : Natural := Shape_At ("http://example.org/MultiShape");
      begin
         Check (M > 0, "MultiShape found");
         if M > 0 then
            declare
               S : SHACL_Ada.Shapes.Shape renames Table.List (M);
            begin
               Check (S.Message_Count = 2,
                      "distinct languages accumulate");
               if S.Message_Count = 2 then
                  --  Quad arrival order is the dataset's, not the
                  --  document's, so assert the set, not the sequence:
                  --  exactly {en, fr}, fr fixed, en is one of its two
                  --  literals (the other was dropped as a duplicate).
                  declare
                     En_Seen, Fr_Seen : Boolean := False;
                     En_Ok, Fr_Ok    : Boolean := True;
                  begin
                     for Position in 1 .. 2 loop
                        declare
                           Lang : constant String :=
                             SHACL_Ada.Terms.Language_Of
                               (S.Messages (Position));
                           Lex : constant String :=
                             SHACL_Ada.Terms.Lexical_Of
                               (S.Messages (Position));
                        begin
                           if Lang = "en" then
                              En_Seen := True;
                              En_Ok := En_Ok
                                and then (Lex = "hello"
                                          or else Lex = "hello again");
                           elsif Lang = "fr" then
                              Fr_Seen := True;
                              Fr_Ok := Fr_Ok and then Lex = "bonjour";
                           else
                              En_Ok := False;
                           end if;
                        end;
                     end loop;
                     Check (En_Seen and then Fr_Seen and then En_Ok and then Fr_Ok,
                            "duplicate language dropped, distinct kept");
                  end;
               end if;
            end;
         end if;
      end;

      declare
         B : Natural := Shape_At ("http://example.org/BareShape");
      begin
         Check (B > 0, "BareShape found");
         if B > 0 then
            declare
               S : SHACL_Ada.Shapes.Shape renames Table.List (B);
            begin
               Check (S.Severity = SHACL_Ada.Shapes.Severity_Violation
                      and then S.Message_Count = 0,
                      "bare shape has defaults");
            end;
         end if;
      end;

      Check_Rejected (Bad_Severity_Document, "bogus severity");
      Check_Rejected
        (Non_Literal_Message_Document, "non-literal message");
      Check_Rejected
        (Too_Many_Messages_Document, "message budget overflow");
   end;

   if Failures = 0 then
      Ada.Text_IO.Put_Line ("all shapes tests passed");
   else
      Ada.Text_IO.Put_Line (Natural'Image (Failures) & " test(s) failed");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Shapes_Tests;
