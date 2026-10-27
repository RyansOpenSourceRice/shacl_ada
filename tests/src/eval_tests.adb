--  SPDX-License-Identifier: Apache-2.0
--
--  Corpus conformance tests: every selected W3C test-suite case is
--  validated through the engine and the report's conformance is
--  compared against the suite's recorded expectation. Cases cover the
--  implemented components over the full Core path grammar (predicate,
--  inverse, sequence, alternative, and the three cardinality forms);
--  report-vocabulary cases (sh:severity, sh:message) and the
--  meta-shapes case (shacl-shacl) are out of scope until the report
--  milestone.

with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Flyology_RDF.Datasets;

with SHACL_Ada.Data;
with SHACL_Ada.Eval;
with SHACL_Ada.Rdf;
with SHACL_Ada.Shapes;
with SHACL_Ada.Terms;
with SHACL_Ada.Validation;

procedure Eval_Tests is
   use type SHACL_Ada.Validation.Error_Kind;
   use type SHACL_Ada.Shapes.Constraint_Kind;
   use type SHACL_Ada.Shapes.Severity_Kind;
   use type SHACL_Ada.Terms.Term;

   use Ada.Text_IO;

   Failures : Natural := 0;

   type Shape_Table_Ref is access all SHACL_Ada.Shapes.Shape_Table;

   Work_Data : constant := 1024;

   package Corpus_Data is new SHACL_Ada.Data (Work_Data);

   procedure To_Graph is new SHACL_Ada.Rdf.Extract_Data (Corpus_Data);

   package Corpus_Eval is new SHACL_Ada.Eval
     (Max_Violations  => 256,
      Max_Path_Values => 256,
      Data            => Corpus_Data);

   --  Deliberately tiny budget: capacity behavior is asserted, not the
   --  report content.
   package Tiny_Eval is new SHACL_Ada.Eval
     (Max_Violations  => 2,
      Max_Path_Values => 16,
      Data            => Corpus_Data);

   Capacity_Hit : Boolean := False;

   type Graph_Ref is access Corpus_Data.Graph;
   type Result_Ref is access Corpus_Eval.Violation_Table;

   type Case_Record is record
      Dir      : access constant String;
      File     : access constant String;
      Conforms : Boolean;
   end record;

   type Case_List is array (Positive range <>) of Case_Record;

   Cases : constant Case_List :=
     (--  node shapes, core/node
      (new String'("node"), new String'("and-001.ttl"), False),
      (new String'("node"), new String'("and-002.ttl"), False),
      (new String'("node"), new String'("class-001.ttl"), False),
      (new String'("node"), new String'("class-002.ttl"), False),
      (new String'("node"), new String'("class-003.ttl"), False),
      (new String'("node"), new String'("closed-001.ttl"), False),
      (new String'("node"), new String'("closed-002.ttl"), False),
      (new String'("node"), new String'("datatype-001.ttl"), False),
      (new String'("node"), new String'("datatype-002.ttl"), False),
      (new String'("node"), new String'("disjoint-001.ttl"), False),
      (new String'("node"), new String'("equals-001.ttl"), False),
      (new String'("node"), new String'("hasValue-001.ttl"), False),
      (new String'("node"), new String'("in-001.ttl"), False),
      (new String'("node"), new String'("languageIn-001.ttl"), False),
      (new String'("node"), new String'("maxExclusive-001.ttl"), False),
      (new String'("node"), new String'("maxInclusive-001.ttl"), False),
      (new String'("node"), new String'("maxLength-001.ttl"), False),
      (new String'("node"), new String'("minExclusive-001.ttl"), False),
      (new String'("node"), new String'("minInclusive-001.ttl"), False),
      (new String'("node"), new String'("minInclusive-002.ttl"), False),
      (new String'("node"), new String'("minInclusive-003.ttl"), False),
      (new String'("node"), new String'("minLength-001.ttl"), False),
      (new String'("node"), new String'("node-001.ttl"), False),
      (new String'("node"), new String'("nodeKind-001.ttl"), False),
      (new String'("node"), new String'("not-001.ttl"), False),
      (new String'("node"), new String'("not-002.ttl"), False),
      (new String'("node"), new String'("or-001.ttl"), False),
      (new String'("node"), new String'("pattern-001.ttl"), False),
      (new String'("node"), new String'("pattern-002.ttl"), False),
      (new String'("node"), new String'("qualified-001.ttl"), False),
      (new String'("node"), new String'("xone-001.ttl"), False),
      (new String'("node"), new String'("xone-duplicate.ttl"), False),
      --  property shapes, core/property
      (new String'("property"), new String'("and-001.ttl"), False),
      (new String'("property"), new String'("class-001.ttl"), False),
      (new String'("property"), new String'("datatype-001.ttl"), False),
      (new String'("property"), new String'("datatype-002.ttl"), False),
      (new String'("property"), new String'("datatype-003.ttl"), False),
      (new String'("property"), new String'("datatype-ill-formed.ttl"), False),
      (new String'("property"), new String'("disjoint-001.ttl"), False),
      (new String'("property"), new String'("equals-001.ttl"), False),
      (new String'("property"), new String'("hasValue-001.ttl"), False),
      (new String'("property"), new String'("in-001.ttl"), False),
      (new String'("property"), new String'("languageIn-001.ttl"), False),
      (new String'("property"), new String'("lessThan-001.ttl"), False),
      (new String'("property"), new String'("lessThan-002.ttl"), False),
      (new String'("property"), new String'("lessThanOrEquals-001.ttl"), False),
      (new String'("property"), new String'("maxCount-001.ttl"), False),
      (new String'("property"), new String'("maxCount-002.ttl"), False),
      (new String'("property"), new String'("maxExclusive-001.ttl"), False),
      (new String'("property"), new String'("maxInclusive-001.ttl"), False),
      (new String'("property"), new String'("maxLength-001.ttl"), False),
      (new String'("property"), new String'("minCount-001.ttl"), False),
      (new String'("property"), new String'("minCount-002.ttl"), True),
      (new String'("property"), new String'("minExclusive-001.ttl"), False),
      (new String'("property"), new String'("minExclusive-002.ttl"), False),
      (new String'("property"), new String'("minLength-001.ttl"), False),
      (new String'("property"), new String'("node-001.ttl"), False),
      (new String'("property"), new String'("node-002.ttl"), False),
      (new String'("property"), new String'("nodeKind-001.ttl"), False),
      (new String'("property"), new String'("not-001.ttl"), False),
      (new String'("property"), new String'("or-001.ttl"), False),
      (new String'("property"), new String'("or-datatypes-001.ttl"), False),
      (new String'("property"), new String'("pattern-001.ttl"), False),
      (new String'("property"), new String'("pattern-002.ttl"), False),
      (new String'("property"), new String'("property-001.ttl"), False),
      (new String'("property"), new String'("qualifiedMinCountDisjoint-001.ttl"), False),
      (new String'("property"), new String'("qualifiedValueShape-001.ttl"), False),
      (new String'("property"), new String'("qualifiedValueShapesDisjoint-001.ttl"), False),
      (new String'("property"), new String'("uniqueLang-001.ttl"), False),
      (new String'("property"), new String'("uniqueLang-002.ttl"), True),
      --  deactivated shapes, core/misc
      (new String'("misc"), new String'("deactivated-001.ttl"), True),
      (new String'("misc"), new String'("deactivated-002.ttl"), False),
      --  path expressions, core/path
      (new String'("path"), new String'("path-alternative-001.ttl"), False),
      (new String'("path"), new String'("path-complex-001.ttl"), False),
      (new String'("path"), new String'("path-complex-002.ttl"), False),
      (new String'("path"), new String'("path-inverse-001.ttl"), False),
      (new String'("path"), new String'("path-oneOrMore-001.ttl"), False),
      (new String'("path"), new String'("path-sequence-001.ttl"), False),
      (new String'("path"), new String'("path-sequence-002.ttl"), False),
      (new String'("path"), new String'("path-sequence-duplicate-001.ttl"), False),
      (new String'("path"), new String'("path-strange-001.ttl"), False),
      (new String'("path"), new String'("path-strange-002.ttl"), False),
      (new String'("path"), new String'("path-unused-001.ttl"), False),
      (new String'("path"), new String'("path-zeroOrMore-001.ttl"), False),
      (new String'("path"), new String'("path-zeroOrOne-001.ttl"), False),
      --  mixed shapes and data, core/complex
      (new String'("complex"), new String'("personexample.ttl"), False));

   function Read_File (Path : String) return String is
      File    : File_Type;
      Content : String (1 .. 262_144);
      Last    : Natural := 0;
   begin
      Open (File, In_File, Path);
      while not End_Of_File (File) loop
         declare
            Line : constant String := Get_Line (File);
         begin
            Content (Last + 1 .. Last + Line'Length) := Line;
            Last := Last + Line'Length;
            Content (Last + 1) := ASCII.LF;
            Last := Last + 1;
         end;
      end loop;
      Close (File);
      return Content (1 .. Last);
   end Read_File;

   Verbose : constant Boolean :=
     Ada.Command_Line.Argument_Count = 2
       and then Ada.Command_Line.Argument (2) = "-v";

   procedure Report_Result
     (Entry_Case : Case_Record; Rpt : Corpus_Eval.Violation_Table)
   is
      use type SHACL_Ada.Shapes.Severity_Kind;
   begin
      --  Every corpus shape omits sh:severity and sh:message, so every
      --  recorded result must carry the defaults: Violation severity
      --  and an auto-generated message.
      for I in 1 .. Rpt.Count loop
         if Rpt.List (I).Severity /= SHACL_Ada.Shapes.Severity_Violation then
            Put_Line ("FAIL " & Entry_Case.Dir.all & "/" & Entry_Case.File.all
                      & ": non-default severity");
            Failures := Failures + 1;
            return;
         end if;
         if SHACL_Ada.Terms.Lexical_Of (Rpt.List (I).Message) = "" then
            Put_Line ("FAIL " & Entry_Case.Dir.all & "/" & Entry_Case.File.all
                      & ": empty message");
            Failures := Failures + 1;
            return;
         end if;
      end loop;
      if not Verbose then
         return;
      end if;
      Ada.Text_IO.Put ("    ");
      Ada.Text_IO.Put (Entry_Case.Dir.all & "/" & Entry_Case.File.all);
      Ada.Text_IO.Put_Line
        (" ->" & Natural'Image (Rpt.Count) & " violations");
      for I in 1 .. Rpt.Count loop
         Ada.Text_IO.Put_Line
           ("      " & SHACL_Ada.Shapes.Constraint_Kind'Image
              (Rpt.List (I).Component));
      end loop;
   end Report_Result;

   procedure Run_File
     (Root       : String;
      Entry_Case : Case_Record;
      Conforms : out Boolean;
      Rpt      : out Corpus_Eval.Violation_Table)
   is
      Path : constant String :=
        Root & "/" & Entry_Case.Dir.all & "/" & Entry_Case.File.all;
      --  Some suite cases keep data and shapes in sibling files
      --  referenced by the manifest; concatenate what exists.
      Data_Path   : constant String :=
        Path (Path'First .. Path'Last - 4) & "-data.ttl";
      Shapes_Path : constant String :=
        Path (Path'First .. Path'Last - 4) & "-shapes.ttl";
      Document  : constant String :=
        Read_File (Path)
        & (if Ada.Directories.Exists (Data_Path)
           then Read_File (Data_Path)
           else "")
        & (if Ada.Directories.Exists (Shapes_Path)
           then Read_File (Shapes_Path)
           else "");
      Dataset   : Flyology_RDF.Datasets.Dataset;
      Loaded    : Boolean;
      Shapes    : constant Shape_Table_Ref :=
        new SHACL_Ada.Shapes.Shape_Table;
      Graph     : constant Graph_Ref := new Corpus_Data.Graph;
      Local     : constant Result_Ref := new Corpus_Eval.Violation_Table;
   begin
      SHACL_Ada.Rdf.Load_Turtle
        (Document, "file://" & Path, Dataset, Loaded);
      if not Loaded then
         raise Constraint_Error with "parse failed: " & Path;
      end if;
      SHACL_Ada.Rdf.Extract_Shapes (Dataset, Shapes.all);
      To_Graph (Dataset, Graph.all);
      declare
         Err : SHACL_Ada.Validation.Error_Kind;
      begin
         Corpus_Eval.Validate (Shapes.all, Graph.all, Local.all, Err);
         if Err /= SHACL_Ada.Validation.None then
            Capacity_Hit := True;
         end if;
      end;
      Rpt := Local.all;
      Conforms := Rpt.Count = 0;
   end Run_File;

   procedure Run_Inline_Shapes
     (Shapes_Doc : String;
      Shapes     : out Shape_Table_Ref;
      Graph      : out Graph_Ref)
   is
      Dataset : Flyology_RDF.Datasets.Dataset;
      Loaded  : Boolean;
   begin
      Shapes := new SHACL_Ada.Shapes.Shape_Table;
      Graph := new Corpus_Data.Graph;
      SHACL_Ada.Rdf.Load_Turtle (Shapes_Doc, "file://inline", Dataset, Loaded);
      if not Loaded then
         raise Constraint_Error with "inline shapes rejected";
      end if;
      SHACL_Ada.Rdf.Extract_Shapes (Dataset, Shapes.all);
      To_Graph (Dataset, Graph.all);
   end Run_Inline_Shapes;

   --  Warning-only results still fail conformance (spec-literal
   --  sh:conforms), and carry the shape's severity and message.
   procedure Check_Report_Surface is
      use type SHACL_Ada.Shapes.Severity_Kind;
      use type SHACL_Ada.Validation.Error_Kind;
      Shapes_Doc : constant String :=
        "@prefix sh: <http://www.w3.org/ns/shacl#> ." & ASCII.LF &
        "@prefix ex: <http://example.org/> ." & ASCII.LF &
        "ex:S a sh:NodeShape ;" & ASCII.LF &
        "  sh:targetNode ex:a ;" & ASCII.LF &
        "  sh:property ex:P ." & ASCII.LF &
        "ex:P a sh:PropertyShape ;" & ASCII.LF &
        "  sh:path ex:p ;" & ASCII.LF &
        "  sh:minCount 1 ;" & ASCII.LF &
        "  sh:severity sh:Warning ;" & ASCII.LF &
        "  sh:message ""mind the gap"" ." & ASCII.LF;
      Shapes : Shape_Table_Ref;
      Graph  : Graph_Ref;
      Local  : constant Result_Ref := new Corpus_Eval.Violation_Table;
      Err    : SHACL_Ada.Validation.Error_Kind;
   begin
      Run_Inline_Shapes (Shapes_Doc, Shapes, Graph);
      Corpus_Eval.Validate (Shapes.all, Graph.all, Local.all, Err);
      if Local.Count /= 1 then
         Put_Line ("FAIL report-surface: count");
         Failures := Failures + 1;
         return;
      end if;
      if Err /= SHACL_Ada.Validation.None then
         Put_Line ("FAIL report-surface: unexpected capacity error");
         Failures := Failures + 1;
      end if;
      if Local.List (1).Severity /= SHACL_Ada.Shapes.Severity_Warning then
         Put_Line ("FAIL report-surface: severity");
         Failures := Failures + 1;
      end if;
      if SHACL_Ada.Terms.Lexical_Of (Local.List (1).Message)
        /= "mind the gap"
      then
         Put_Line ("FAIL report-surface: message passthrough");
         Failures := Failures + 1;
      end if;
      if Corpus_Eval.Conforms (Local.all) then
         Put_Line ("FAIL report-surface: warning-only conforms");
         Failures := Failures + 1;
      else
         Put_Line ("PASS report-surface: warning severity, message, no conforms");
      end if;
   end Check_Report_Surface;

   --  A full table stops recording with Capacity_Exceeded and an exact
   --  regrow budget; revalidating with that budget is complete.
   procedure Check_Capacity is
      use type SHACL_Ada.Validation.Error_Kind;
      Shapes_Doc : constant String :=
        "@prefix sh: <http://www.w3.org/ns/shacl#> ." & ASCII.LF &
        "@prefix ex: <http://example.org/> ." & ASCII.LF &
        "ex:S a sh:NodeShape ;" & ASCII.LF &
        "  sh:targetNode ex:a, ex:b, ex:c ;" & ASCII.LF &
        "  sh:property ex:P ." & ASCII.LF &
        "ex:P a sh:PropertyShape ;" & ASCII.LF &
        "  sh:path ex:p ;" & ASCII.LF &
        "  sh:minCount 1 ." & ASCII.LF;
      Shapes : Shape_Table_Ref;
      Graph  : Graph_Ref;
      Small  : Tiny_Eval.Violation_Table;
      Small_Err : SHACL_Ada.Validation.Error_Kind;
      Full   : Corpus_Eval.Violation_Table;
      Full_Err  : SHACL_Ada.Validation.Error_Kind;
   begin
      Run_Inline_Shapes (Shapes_Doc, Shapes, Graph);
      Tiny_Eval.Validate (Shapes.all, Graph.all, Small, Small_Err);
      if Small.Count /= 2
        or else Small_Err /= SHACL_Ada.Validation.Capacity_Exceeded
        or else not Tiny_Eval.Capacity_Exceeded (Small)
        or else Tiny_Eval.Total_Results (Small) /= 3
      then
         Put_Line ("FAIL capacity: stop-with-error and exact regrow budget");
         Failures := Failures + 1;
         return;
      end if;
      Corpus_Eval.Validate (Shapes.all, Graph.all, Full, Full_Err);
      if Full.Count /= 3 or else Full_Err /= SHACL_Ada.Validation.None then
         Put_Line ("FAIL capacity: regrown budget is not complete");
         Failures := Failures + 1;
      else
         Put_Line ("PASS capacity: exceeded, total 3, regrown complete");
      end if;
   end Check_Capacity;

  --  Wrapper/indexed agreement lockstep: both paths must produce
  --  byte-identical tables (same engine, same inputs). Guards future
  --  divergence; the W3C suite itself remains the independent oracle.
  procedure Check_Indexed_Agreement
    (Root : String; Entry_Case : Case_Record)
  is
    Path : constant String :=
      Root & "/" & Entry_Case.Dir.all & "/" & Entry_Case.File.all;
    Data_Path : constant String :=
      Path (Path'First .. Path'Last - 4) & "-data.ttl";
    Shapes_Path : constant String :=
      Path (Path'First .. Path'Last - 4) & "-shapes.ttl";
    Document  : constant String :=
      Read_File (Path)
      & (if Ada.Directories.Exists (Data_Path)
         then Read_File (Data_Path)
         else "")
      & (if Ada.Directories.Exists (Shapes_Path)
         then Read_File (Shapes_Path)
         else "");
    Dataset  : Flyology_RDF.Datasets.Dataset;
    Loaded   : Boolean;
    Shapes_A : constant Shape_Table_Ref := new SHACL_Ada.Shapes.Shape_Table;
    Shapes_B : constant Shape_Table_Ref := new SHACL_Ada.Shapes.Shape_Table;
    Graph    : constant Graph_Ref := new Corpus_Data.Graph;
    Rpt_A    : constant Result_Ref := new Corpus_Eval.Violation_Table;
    Rpt_B    : constant Result_Ref := new Corpus_Eval.Violation_Table;
    Err_A    : SHACL_Ada.Validation.Error_Kind;
    Err_B    : SHACL_Ada.Validation.Error_Kind;

    function Same_Entry (I : Positive) return Boolean is
      VA : constant SHACL_Ada.Validation.Violation := Rpt_A.List (I);
      VB : constant SHACL_Ada.Validation.Violation := Rpt_B.List (I);
    begin
      if VA.Focus_Node /= VB.Focus_Node
        or else VA.Value_Node /= VB.Value_Node
        or else VA.Path /= VB.Path
        or else VA.Source_Shape /= VB.Source_Shape
        or else VA.Component /= VB.Component
        or else VA.Severity /= VB.Severity
        or else VA.Message /= VB.Message
        or else VA.Detail_Count /= VB.Detail_Count
      then
         return False;
      end if;
      for D in 1 .. VA.Detail_Count loop
         if VA.Details (D) /= VB.Details (D) then
            return False;
         end if;
      end loop;
      return True;
    end Same_Entry;
  begin
    SHACL_Ada.Rdf.Load_Turtle
      (Document, "file://" & Path, Dataset, Loaded);
    if not Loaded then
       Put_Line ("FAIL agreement: parse failed: " & Path);
       Failures := Failures + 1;
       return;
    end if;
    SHACL_Ada.Rdf.Extract_Shapes (Dataset, Shapes_A.all);
    To_Graph (Dataset, Graph.all);
    Shapes_B.all := Shapes_A.all;
    Corpus_Eval.Validate (Shapes_A.all, Graph.all, Rpt_A.all, Err_A);
    SHACL_Ada.Shapes.Finalize_Index (Shapes_B.all);
    Corpus_Eval.Validate_Indexed (Shapes_B.all, Graph.all, Rpt_B.all, Err_B);
    if Rpt_A.Count /= Rpt_B.Count
      or else Err_A /= Err_B
      or else Rpt_A.Dropped /= Rpt_B.Dropped
    then
       Put_Line ("FAIL agreement: count/error: " & Path);
       Failures := Failures + 1;
       return;
    end if;
    for I in 1 .. Rpt_A.Count loop
       if not Same_Entry (I) then
          Put_Line ("FAIL agreement: entry" & I'Image & ": " & Path);
          Failures := Failures + 1;
          return;
       end if;
    end loop;
  end Check_Indexed_Agreement;

  --  sh:detail: an sh:node failure links its fresh inner results.
  procedure Check_Detail is
    use type SHACL_Ada.Shapes.Constraint_Kind;
    Shapes_Doc : constant String :=
      "@prefix sh: <http://www.w3.org/ns/shacl#> ." & ASCII.LF &
      "@prefix ex: <http://example.org/> ." & ASCII.LF &
      "ex:S a sh:NodeShape ;" & ASCII.LF &
      "  sh:targetNode ex:a ;" & ASCII.LF &
      "  sh:node ex:Inner ." & ASCII.LF &
      "ex:Inner a sh:NodeShape ;" & ASCII.LF &
      "  sh:property ex:P ." & ASCII.LF &
      "ex:P a sh:PropertyShape ;" & ASCII.LF &
      "  sh:path ex:p ;" & ASCII.LF &
      "  sh:minCount 1 ." & ASCII.LF;
    Shapes : Shape_Table_Ref;
    Graph  : Graph_Ref;
    Local  : constant Result_Ref := new Corpus_Eval.Violation_Table;
    Err    : SHACL_Ada.Validation.Error_Kind;
  begin
    Run_Inline_Shapes (Shapes_Doc, Shapes, Graph);
    Corpus_Eval.Validate (Shapes.all, Graph.all, Local.all, Err);
    if Local.Count /= 2 then
       Put_Line ("FAIL detail: count");
       Failures := Failures + 1;
       return;
    end if;
    if Local.List (1).Component /= SHACL_Ada.Shapes.Min_Count
      or else Local.List (2).Component /= SHACL_Ada.Shapes.Node_Link
    then
       Put_Line ("FAIL detail: inner-then-outer order");
       Failures := Failures + 1;
       return;
    end if;
    if Local.List (2).Detail_Count /= 1
      or else Local.List (2).Details (1) /= 1
    then
       Put_Line ("FAIL detail: parent links inner result");
       Failures := Failures + 1;
    else
       Put_Line ("PASS detail: sh:node links inner result");
    end if;
  end Check_Detail;

begin
   declare
      Root : constant String :=
        (if Ada.Command_Line.Argument_Count = 1
         then Ada.Command_Line.Argument (1)
         else "../corpora/data-shapes-test-suite/tests/core");
   begin
      for Index in Cases'Range loop
         declare
            Got       : Boolean;
            Got_Table : Corpus_Eval.Violation_Table;
            Expected  : constant Boolean := Cases (Index).Conforms;
            Label    : constant String :=
              Cases (Index).Dir.all & "/" & Cases (Index).File.all
              & (if Expected then " conforms" else " violates");
         begin
            Run_File (Root, Cases (Index), Got, Got_Table);
            Report_Result (Cases (Index), Got_Table);
            if Got = Expected then
               Put_Line ("PASS " & Label);
            else
               Put_Line ("FAIL " & Label);
               Failures := Failures + 1;
            end if;
            Check_Indexed_Agreement (Root, Cases (Index));
         end;
      end loop;
   end;

   Put_Line
     ("eval corpus:" & Natural'Image (Cases'Length) & " cases,"
      & Natural'Image (Failures) & " failures");
   if Capacity_Hit then
      Put_Line ("FAIL capacity: a corpus case exceeded its budget");
      Failures := Failures + 1;
   end if;
   Check_Report_Surface;
   Check_Capacity;
   Check_Detail;
   if Failures > 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Eval_Tests;
