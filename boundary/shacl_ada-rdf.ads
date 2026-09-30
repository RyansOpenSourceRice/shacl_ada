--  SPDX-License-Identifier: Apache-2.0
--
--  Boundary layer between flyology_rdf and the SPARK core.
--
--  This unit is deliberately outside SPARK: it consumes the third-party
--  RDF syntax library and converts its terms into the pure core's model.
--  The validator core never sees RDF syntax. The traversal state is
--  library-level, so extraction is sequential, not task-safe.

with Flyology_RDF.Datasets;

with SHACL_Ada.Data;
with SHACL_Ada.Shapes;

package SHACL_Ada.Rdf is

   pragma SPARK_Mode (Off);

   --  Raised when a shapes graph exceeds the published bounds: a term is
   --  longer than Terms.Max_Text_Length, a list is malformed, or the
   --  shape, target, constraint, pending, or list-entry tables overflow.
   --  Extract_Data also raises it when the data graph outgrows the
   --  caller's Data instantiation.
   Boundary_Error : exception;

   --  Parse one Turtle document into a dataset. Ok is False when the
   --  document is rejected; the diagnostic goes to standard error.
   procedure Load_Turtle
     (Document : String;
      Base_IRI : String;
      Into     : out Flyology_RDF.Datasets.Dataset;
      Ok       : out Boolean);

   --  Extract every node shape and property shape of the default graph of
   --  this dataset, with targets and Core constraint parameters. Quads in
   --  named graphs are ignored. Raises Boundary_Error on overflow.
   procedure Extract_Shapes
     (Graph : Flyology_RDF.Datasets.Dataset;
      Into  : out SHACL_Ada.Shapes.Shape_Table);

   --  Copy the default graph of this dataset into the caller's Data
   --  instantiation. Quads in named graphs are ignored. Raises
   --  Boundary_Error when the graph exceeds Data's Max_Triples.
   generic
      with package Data is new SHACL_Ada.Data (<>);
   procedure Extract_Data
     (Graph  : Flyology_RDF.Datasets.Dataset;
      Result : out Data.Graph);

end SHACL_Ada.Rdf;
