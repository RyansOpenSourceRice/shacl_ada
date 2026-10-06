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

procedure Eval_Tests is

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
   begin
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
      Corpus_Eval.Validate (Shapes.all, Graph.all, Local.all);
      Rpt := Local.all;
      Conforms := Rpt.Count = 0;
   end Run_File;

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
         end;
      end loop;
   end;

   Put_Line
     ("eval corpus:" & Natural'Image (Cases'Length) & " cases,"
      & Natural'Image (Failures) & " failures");
   if Failures > 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Eval_Tests;
