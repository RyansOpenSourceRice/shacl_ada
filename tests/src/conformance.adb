--  SPDX-License-Identifier: Apache-2.0
--
--  Conformance smoke runner: parses a shapes graph and a data graph from
--  Turtle, extracts the shapes, and reports extraction counts. Exit 0 on
--  success, 1 on rejection or boundary error.

with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Flyology_RDF.Datasets;

with SHACL_Ada.Rdf;
with SHACL_Ada.Shapes;

procedure Conformance is

   use Ada.Strings.Unbounded;
   use Ada.Text_IO;

   procedure Fail (Message : String) is
   begin
      Put_Line (Message);
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end Fail;

   function Read_File (Path : String) return String is
      File    : File_Type;
      Content : Unbounded_String;
   begin
      Open (File, In_File, Path);
      while not End_Of_File (File) loop
         Append (Content, Get_Line (File) & ASCII.LF);
      end loop;
      Close (File);
      return To_String (Content);
   exception
      when Error : others =>
         if Is_Open (File) then
            Close (File);
         end if;
         Put_Line ("cannot read " & Path & ": "
                   & Ada.Exceptions.Exception_Message (Error));
         raise;
   end Read_File;

begin
   if Ada.Command_Line.Argument_Count /= 2 then
      Fail ("usage: conformance <shapes.ttl> <data.ttl>");
      return;
   end if;

   declare
      Shapes_Document : constant String :=
        Read_File (Ada.Command_Line.Argument (1));
      Data_Document : constant String :=
        Read_File (Ada.Command_Line.Argument (2));

      --  A Shape_Table is a few megabytes; it lives on the heap, never on
      --  a default-size stack.
      type Shape_Table_Ref is access all SHACL_Ada.Shapes.Shape_Table;

      Shapes_Graph : Flyology_RDF.Datasets.Dataset;
      Data_Graph   : Flyology_RDF.Datasets.Dataset;
      Ok           : Boolean;
      Table        : constant Shape_Table_Ref :=
        new SHACL_Ada.Shapes.Shape_Table;
      Targets      : Natural := 0;
   begin
      SHACL_Ada.Rdf.Load_Turtle
        (Shapes_Document, "file://" & Ada.Command_Line.Argument (1),
         Shapes_Graph, Ok);
      if not Ok then
         Fail ("shapes graph rejected");
         return;
      end if;

      SHACL_Ada.Rdf.Load_Turtle
        (Data_Document, "file://" & Ada.Command_Line.Argument (2),
         Data_Graph, Ok);
      if not Ok then
         Fail ("data graph rejected");
         return;
      end if;

      SHACL_Ada.Rdf.Extract_Shapes (Shapes_Graph, Table.all);

      for Index in 1 .. Table.Count loop
         Targets := Targets + Table.all.List (Index).Target_Count;
      end loop;

      Put_Line ("shapes graph quads:"
                & Flyology_RDF.Datasets.Length (Shapes_Graph)'Image);
      Put_Line ("data graph quads:"
                & Flyology_RDF.Datasets.Length (Data_Graph)'Image);
      Put_Line ("shapes extracted:" & Table.all.Count'Image);
      Put_Line ("targets:" & Targets'Image);
      Put_Line ("conformance run complete");
   exception
      when SHACL_Ada.Rdf.Boundary_Error =>
         Fail ("boundary limit exceeded");
   end;

exception
   when others =>
      null;  -- exit status already set by Fail on the failure paths
end Conformance;
