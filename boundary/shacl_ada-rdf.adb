--  SPDX-License-Identifier: Apache-2.0

with Ada.Text_IO;

with Flyology_RDF.IRIs;
with Flyology_RDF.Quads;
with Flyology_RDF.Terms;
with Flyology_RDF.Turtle_Parsers;

with SHACL_Ada.Terms;

package body SHACL_Ada.Rdf is

   Shacl_Ns   : constant String := "http://www.w3.org/ns/shacl#";
   Rdf_Ns     : constant String := "http://www.w3.org/1999/02/22-rdf-syntax-ns#";
   Rdf_Type   : constant String := Rdf_Ns & "type";
   Rdf_First  : constant String := Rdf_Ns & "first";
   Rdf_Rest   : constant String := Rdf_Ns & "rest";
   Rdf_Nil    : constant String := Rdf_Ns & "nil";
   Xsd_String : constant String := "http://www.w3.org/2001/XMLSchema#string";

   subtype Shacl_Term is SHACL_Ada.Terms.Term;
   subtype FTerm  is Flyology_RDF.Terms.Term;

   use type SHACL_Ada.Terms.Term_Kind;
   use type Shapes.Constraint_Kind;
   use type Flyology_RDF.Turtle_Parsers.Parse_Status;

   function Is_Iri (Value : Shacl_Term; Name : String) return Boolean is
     (SHACL_Ada.Terms.Kind_Of (Value) = SHACL_Ada.Terms.Iri
      and then SHACL_Ada.Terms.Name_Of (Value) = Name);

   --  Convert one flyology term into a core term. Quoted triple terms are
   --  out of scope for SHACL 1.0 Core and convert to the empty term.
   function Convert (Value : FTerm) return Shacl_Term is
      use type Flyology_RDF.Terms.Term_Kind;
      Overlong : exception renames Boundary_Error;
   begin
      case Flyology_RDF.Terms.Kind (Value) is
         when Flyology_RDF.Terms.IRI_Kind =>
            declare
               Name : constant String :=
                 Flyology_RDF.IRIs.To_UTF_8 (Flyology_RDF.Terms.IRI_Value (Value));
            begin
               if Name'Length > SHACL_Ada.Terms.Max_Text_Length then
                  raise Overlong;
               end if;
               return SHACL_Ada.Terms.Make_Iri (Name);
            end;
         when Flyology_RDF.Terms.Blank_Node_Kind =>
            declare
               Label : constant String := Flyology_RDF.Terms.Label (Value);
            begin
               if Label'Length > SHACL_Ada.Terms.Max_Text_Length then
                  raise Overlong;
               end if;
               return SHACL_Ada.Terms.Make_Blank_Node (Label);
            end;
         when Flyology_RDF.Terms.Literal_Kind =>
            declare
               Lexical : constant String := Flyology_RDF.Terms.Lexical_Form (Value);
            begin
               if Lexical'Length > SHACL_Ada.Terms.Max_Text_Length then
                  raise Overlong;
               end if;
               if Flyology_RDF.Terms.Has_Language (Value) then
                  declare
                     Tag : constant String := Flyology_RDF.Terms.Language (Value);
                  begin
                     if Tag'Length > SHACL_Ada.Terms.Max_Text_Length then
                        raise Overlong;
                     end if;
                     return SHACL_Ada.Terms.Make_Literal (Lexical, Language => Tag);
                  end;
               end if;
               declare
                 Datatype : constant String :=
                   Flyology_RDF.IRIs.To_UTF_8 (Flyology_RDF.Terms.Datatype (Value));
               begin
                  if Datatype = Xsd_String then
                     return SHACL_Ada.Terms.Make_Literal (Lexical);
                  elsif Datatype'Length > SHACL_Ada.Terms.Max_Text_Length then
                     raise Overlong;
                  else
                     return SHACL_Ada.Terms.Make_Literal (Lexical, Datatype => Datatype);
                  end if;
               end;
            end;
         when others =>
            return SHACL_Ada.Terms.Empty;
      end case;
   end Convert;

   --  Deferred RDF-list resolution. sh:in, sh:languageIn,
   --  sh:ignoredProperties, sh:and, sh:or, and sh:xone point at list
   --  heads; members become individual constraints once all triples of
   --  the dataset are known.
   type Pending_Kind is
     (Pending_In, Pending_Language_In, Pending_Ignored,
      Pending_And, Pending_Or, Pending_Xone);

   Max_Pending      : constant := 64;
   Max_List_Entries : constant := 1_024;
   Max_Referenced   : constant := 128;

   type Pending_Item is record
      Shape_Index : Natural     := 0;
      Kind        : Pending_Kind := Pending_In;
      Head        : FTerm;
   end record;

   type Pending_Array is array (1 .. Max_Pending) of Pending_Item;

   type List_Entry is record
      Node      : FTerm;
      First     : FTerm;
      Rest      : FTerm;
      Has_First : Boolean := False;
      Has_Rest  : Boolean := False;
   end record;

   type List_Array is array (1 .. Max_List_Entries) of List_Entry;

   type Reference_Item is record
      Node        : Shacl_Term := SHACL_Ada.Terms.Empty;
      As_Property : Boolean    := False;
   end record;

   type Reference_Array is array (1 .. Max_Referenced) of Reference_Item;

   --  Library-level traversal state; extraction is sequential.
   Table_Object : aliased Shapes.Shape_Table;

   Pending_Count : Natural := 0;
   Pending       : Pending_Array;

   List_Count : Natural := 0;
   Lists      : List_Array;

   Reference_Count : Natural := 0;
   References      : Reference_Array;

   procedure Reset_Scan is
   begin
      Table_Object := (List => (others => <>), Count => 0);
      Pending_Count := 0;
      List_Count := 0;
      Reference_Count := 0;
   end Reset_Scan;

   function Ensure (Node : Shacl_Term) return Natural is
      Found : constant Natural := Shapes.Find (Table_Object, Node);
   begin
      if Found > 0 then
         return Found;
      end if;
      if Table_Object.Count >= Shapes.Max_Shapes then
         raise Boundary_Error;
      end if;
      Table_Object.Count := Table_Object.Count + 1;
      Table_Object.List (Table_Object.Count).Node := Node;
      return Table_Object.Count;
   end Ensure;

   procedure Add_Constraint
     (Index : Natural; Kind : Shapes.Constraint_Kind;
      Value : Shacl_Term; Extra : Shacl_Term := SHACL_Ada.Terms.Empty)
   is
      Shape : Shapes.Shape renames Table_Object.List (Index);
   begin
      if Shape.Constraint_Count >= Shapes.Max_Constraints_Per_Shape then
         raise Boundary_Error;
      end if;
      Shape.Constraint_Count := Shape.Constraint_Count + 1;
      Shape.Constraints (Shape.Constraint_Count) :=
        (Kind => Kind, Value => Value, Extra => Extra);
   end Add_Constraint;

   procedure Add_Target
     (Index : Natural; Kind : Shapes.Target_Kind; Value : Shacl_Term)
   is
      Shape : Shapes.Shape renames Table_Object.List (Index);
   begin
      if Shape.Target_Count >= Shapes.Max_Targets_Per_Shape then
         raise Boundary_Error;
      end if;
      Shape.Target_Count := Shape.Target_Count + 1;
      Shape.Targets (Shape.Target_Count) := (Kind => Kind, Value => Value);
   end Add_Target;

   procedure Mark_Reference (Node : Shacl_Term; As_Property : Boolean) is
   begin
      if SHACL_Ada.Terms.Is_Empty (Node) then
         return;
      end if;
      if Reference_Count >= Max_Referenced then
         raise Boundary_Error;
      end if;
      Reference_Count := Reference_Count + 1;
      References (Reference_Count) := (Node => Node, As_Property => As_Property);
   end Mark_Reference;

   procedure Add_Pending (Index : Natural; Kind : Pending_Kind; Head : FTerm) is
   begin
      if Pending_Count >= Max_Pending then
         raise Boundary_Error;
      end if;
      Pending_Count := Pending_Count + 1;
      Pending (Pending_Count) := (Shape_Index => Index, Kind => Kind, Head => Head);
   end Add_Pending;

   --  Create-or-update semantics: rdf:first and rdf:rest arrive as
   --  separate triples for the same list cell, so each records its own
   --  field on the entry keyed by the cell node.
   procedure Record_First (Node, Value : FTerm) is
      use type Flyology_RDF.Terms.Term;
   begin
      for Position in 1 .. List_Count loop
         if Lists (Position).Node = Node then
            Lists (Position).First := Value;
            Lists (Position).Has_First := True;
            return;
         end if;
      end loop;
      if List_Count >= Max_List_Entries then
         raise Boundary_Error;
      end if;
      List_Count := List_Count + 1;
      Lists (List_Count) :=
        (Node => Node, First => Value, Has_First => True, others => <>);
   end Record_First;

   procedure Record_Rest (Node, Value : FTerm) is
      use type Flyology_RDF.Terms.Term;
   begin
      for Position in 1 .. List_Count loop
         if Lists (Position).Node = Node then
            Lists (Position).Rest := Value;
            Lists (Position).Has_Rest := True;
            return;
         end if;
      end loop;
      if List_Count >= Max_List_Entries then
         raise Boundary_Error;
      end if;
      List_Count := List_Count + 1;
      Lists (List_Count) :=
        (Node => Node, Rest => Value, Has_Rest => True, others => <>);
   end Record_Rest;

   procedure Visit_Quad (Statement : Flyology_RDF.Quads.Quad) is
      use type Flyology_RDF.Quads.Graph_Name_Kind;
      Graph : constant Flyology_RDF.Quads.Graph_Name :=
        Flyology_RDF.Quads.Graph (Statement);
   begin
      --  The shapes graph is the default graph; named graphs are ignored.
      if Flyology_RDF.Quads.Kind (Graph) /= Flyology_RDF.Quads.Default_Graph_Kind then
         return;
      end if;

      declare
         P : constant String :=
           Flyology_RDF.IRIs.To_UTF_8 (Flyology_RDF.Quads.Predicate (Statement));
         Subject : constant Shacl_Term :=
           Convert (Flyology_RDF.Quads.Subject (Statement));
         Object : constant Shacl_Term :=
           Convert (Flyology_RDF.Quads.Object (Statement));
      begin
         if P = Rdf_First then
            Record_First
              (Flyology_RDF.Quads.Subject (Statement),
               Flyology_RDF.Quads.Object (Statement));
            return;
         elsif P = Rdf_Rest then
            Record_Rest
              (Flyology_RDF.Quads.Subject (Statement),
               Flyology_RDF.Quads.Object (Statement));
            return;
         end if;

         if P = Rdf_Type then
            if Is_Iri (Object, Shacl_Ns & "NodeShape") then
               declare
                 Index : constant Natural := Ensure (Subject);
               begin
                  Table_Object.List (Index).Is_Property_Shape := False;
               end;
            elsif Is_Iri (Object, Shacl_Ns & "PropertyShape") then
               declare
                 Index : constant Natural := Ensure (Subject);
               begin
                  Table_Object.List (Index).Is_Property_Shape := True;
               end;
            end if;
            return;
         end if;

         if P'Length <= Shacl_Ns'Length
           or else P (P'First .. P'First + Shacl_Ns'Length - 1) /= Shacl_Ns
         then
            return;
         end if;

         declare
            Suffix : constant String :=
              P (P'First + Shacl_Ns'Length .. P'Last);
            Index  : constant Natural := Ensure (Subject);
         begin
            if Suffix = "path" then
               Table_Object.List (Index).Has_Path := True;
               Table_Object.List (Index).Path := Object;
               Table_Object.List (Index).Is_Property_Shape := True;

            elsif Suffix = "targetNode" then
               Add_Target (Index, Shapes.Target_Node, Object);
            elsif Suffix = "targetClass" then
               Add_Target (Index, Shapes.Target_Class, Object);
            elsif Suffix = "targetSubjectsOf" then
               Add_Target (Index, Shapes.Target_Subjects_Of, Object);
            elsif Suffix = "targetObjectsOf" then
               Add_Target (Index, Shapes.Target_Objects_Of, Object);

            elsif Suffix = "property" then
               Add_Constraint (Index, Shapes.Property_Link, Object);
               Mark_Reference (Object, As_Property => True);
            elsif Suffix = "node" then
               Add_Constraint (Index, Shapes.Node_Link, Object);
               Mark_Reference (Object, As_Property => False);
            elsif Suffix = "not" then
               Add_Constraint (Index, Shapes.Not_Shape, Object);
               Mark_Reference (Object, As_Property => False);

            elsif Suffix = "in" then
               Add_Pending (Index, Pending_In,
                            Flyology_RDF.Quads.Object (Statement));
            elsif Suffix = "languageIn" then
               Add_Pending (Index, Pending_Language_In,
                            Flyology_RDF.Quads.Object (Statement));
            elsif Suffix = "ignoredProperties" then
               Add_Pending (Index, Pending_Ignored,
                            Flyology_RDF.Quads.Object (Statement));
            elsif Suffix = "and" then
               Add_Pending (Index, Pending_And,
                            Flyology_RDF.Quads.Object (Statement));
            elsif Suffix = "or" then
               Add_Pending (Index, Pending_Or,
                            Flyology_RDF.Quads.Object (Statement));
            elsif Suffix = "xone" then
               Add_Pending (Index, Pending_Xone,
                            Flyology_RDF.Quads.Object (Statement));

            elsif Suffix = "pattern" then
               Add_Constraint (Index, Shapes.Pattern_Param, Object);
            elsif Suffix = "flags" then
               declare
                  Shape : Shapes.Shape renames Table_Object.List (Index);
               begin
                  for Position in 1 .. Shape.Constraint_Count loop
                     if Shape.Constraints (Position).Kind = Shapes.Pattern_Param
                       and then SHACL_Ada.Terms.Is_Empty
                                  (Shape.Constraints (Position).Extra)
                     then
                        Shape.Constraints (Position).Extra := Object;
                        exit;
                     end if;
                  end loop;
               end;

            elsif Suffix = "minCount" then
               Add_Constraint (Index, Shapes.Min_Count, Object);
            elsif Suffix = "maxCount" then
               Add_Constraint (Index, Shapes.Max_Count, Object);
            elsif Suffix = "minExclusive" then
               Add_Constraint (Index, Shapes.Min_Exclusive, Object);
            elsif Suffix = "maxExclusive" then
               Add_Constraint (Index, Shapes.Max_Exclusive, Object);
            elsif Suffix = "minInclusive" then
               Add_Constraint (Index, Shapes.Min_Inclusive, Object);
            elsif Suffix = "maxInclusive" then
               Add_Constraint (Index, Shapes.Max_Inclusive, Object);
            elsif Suffix = "minLength" then
               Add_Constraint (Index, Shapes.Min_Length, Object);
            elsif Suffix = "maxLength" then
               Add_Constraint (Index, Shapes.Max_Length, Object);
            elsif Suffix = "uniqueLang" then
               Add_Constraint (Index, Shapes.Unique_Lang, Object);
            elsif Suffix = "datatype" then
               Add_Constraint (Index, Shapes.Datatype_Param, Object);
            elsif Suffix = "class" then
               Add_Constraint (Index, Shapes.Class_Param, Object);
            elsif Suffix = "nodeKind" then
               Add_Constraint (Index, Shapes.Node_Kind_Param, Object);
            elsif Suffix = "equals" then
               Add_Constraint (Index, Shapes.Equals_Param, Object);
            elsif Suffix = "disjoint" then
               Add_Constraint (Index, Shapes.Disjoint_Param, Object);
            elsif Suffix = "lessThan" then
               Add_Constraint (Index, Shapes.Less_Than, Object);
            elsif Suffix = "lessThanOrEquals" then
               Add_Constraint (Index, Shapes.Less_Than_Or_Equals, Object);
            elsif Suffix = "closed" then
               Add_Constraint (Index, Shapes.Closed_Param, Object);
            elsif Suffix = "hasValue" then
               Add_Constraint (Index, Shapes.Has_Value_Param, Object);
            elsif Suffix = "qualifiedValueShape" then
               Add_Constraint (Index, Shapes.Qualified_Value_Shape, Object);
               Mark_Reference (Object, As_Property => False);
            elsif Suffix = "qualifiedValueShapesDisjoint" then
               Add_Constraint (Index, Shapes.Qualified_Shapes_Disjoint, Object);
            elsif Suffix = "qualifiedMinCount" then
               Add_Constraint (Index, Shapes.Qualified_Min_Count, Object);
            elsif Suffix = "qualifiedMaxCount" then
               Add_Constraint (Index, Shapes.Qualified_Max_Count, Object);
            end if;
            --  Other SHACL vocabulary (sh:name, sh:message, sh:severity,
            --  sh:order, sh:deactivated, sh:description, sh:group,
            --  sh:resultSeverity, ...) is documentation and reporting
            --  surface, not constraint parameters; it is ignored here.
         end;
      end;
   end Visit_Quad;

   function Lookup_List (Node : FTerm) return List_Entry is
      use type Flyology_RDF.Terms.Term;
   begin
      for Position in 1 .. List_Count loop
         if Lists (Position).Node = Node then
            return Lists (Position);
         end if;
      end loop;
      raise Boundary_Error;
   end Lookup_List;

   function Member_Kind (Of_Pending : Pending_Kind) return Shapes.Constraint_Kind is
     ((case Of_Pending is
         when Pending_In          => Shapes.In_Member,
         when Pending_Language_In => Shapes.Language_In,
         when Pending_Ignored     => Shapes.Ignored_Property,
         when Pending_And         => Shapes.And_Shape,
         when Pending_Or          => Shapes.Or_Shape,
         when Pending_Xone        => Shapes.Xone_Shape));

   procedure Resolve_List (Item : Pending_Item) is
      use type Flyology_RDF.Terms.Term;
      Nil : constant FTerm :=
        Flyology_RDF.Terms.IRI_Term (Flyology_RDF.IRIs.From_UTF_8 (Rdf_Nil));
      Cursor : FTerm := Item.Head;
      Guard  : Natural := 0;
   begin
      loop
         declare
            Link : constant List_Entry := Lookup_List (Cursor);
         begin
            if not Link.Has_First then
               raise Boundary_Error;
            end if;
            Add_Constraint
              (Item.Shape_Index, Member_Kind (Item.Kind), Convert (Link.First));
            if Item.Kind in Pending_And | Pending_Or | Pending_Xone then
               Mark_Reference (Convert (Link.First), As_Property => False);
            end if;
            if not Link.Has_Rest then
               raise Boundary_Error;
            end if;
            exit when Link.Rest = Nil;
            Cursor := Link.Rest;
         end;
         Guard := Guard + 1;
         if Guard > Max_List_Entries then
            raise Boundary_Error;
         end if;
      end loop;
   end Resolve_List;

   procedure Finalize is
   begin
      for Position in 1 .. Pending_Count loop
         Resolve_List (Pending (Position));
      end loop;
      for Position in 1 .. Reference_Count loop
         if not SHACL_Ada.Terms.Is_Empty (References (Position).Node) then
            declare
               Index : constant Natural :=
                 Ensure (References (Position).Node);
            begin
               if References (Position).As_Property then
                  Table_Object.List (Index).Is_Property_Shape := True;
               end if;
            end;
         end if;
      end loop;
   end Finalize;

   procedure Extract_Shapes
     (Graph : Flyology_RDF.Datasets.Dataset;
      Into  : out Shapes.Shape_Table)
   is
   begin
      Reset_Scan;
      Flyology_RDF.Datasets.Iterate (Graph, Visit_Quad'Access);
      Finalize;
      Into := Table_Object;
      Reset_Scan;
   exception
      when others =>
         Reset_Scan;
         raise;
   end Extract_Shapes;

   --  Data-graph extraction -----------------------------------------------

   procedure Extract_Data
     (Graph  : Flyology_RDF.Datasets.Dataset;
      Result : out Data.Graph)
   is
      procedure Visit (Statement : Flyology_RDF.Quads.Quad) is
         use type Flyology_RDF.Quads.Graph_Name_Kind;
         G : constant Flyology_RDF.Quads.Graph_Name :=
           Flyology_RDF.Quads.Graph (Statement);
         P_Name : constant String :=
           Flyology_RDF.IRIs.To_UTF_8 (Flyology_RDF.Quads.Predicate (Statement));
      begin
         --  The data graph is the default graph; named graphs are ignored.
         if Flyology_RDF.Quads.Kind (G)
              /= Flyology_RDF.Quads.Default_Graph_Kind
         then
            return;
         end if;
         if Data.Full (Result) then
            raise Boundary_Error;
         end if;
         Data.Insert
           (Result,
            (Subject   => Convert (Flyology_RDF.Quads.Subject (Statement)),
             Predicate => SHACL_Ada.Terms.Make_Iri (P_Name),
             Object    => Convert (Flyology_RDF.Quads.Object (Statement))));
      end Visit;
   begin
      Result := (Count => 0, List => (others => <>));
      Flyology_RDF.Datasets.Iterate (Graph, Visit'Access);
   end Extract_Data;

   --  Turtle loading ------------------------------------------------------------

   type Collector is limited new Flyology_RDF.Turtle_Parsers.Event_Sink with record
      Data   : Flyology_RDF.Datasets.Dataset := Flyology_RDF.Datasets.Empty;
      Failed : Boolean := False;
   end record;

   overriding procedure On_Graph_Declaration
     (Target : in out Collector;
      Graph  : Flyology_RDF.Quads.Graph_Name;
      Span   : Flyology_RDF.Turtle_Parsers.Source_Span)
   is null;

   overriding procedure On_Quad
     (Target : in out Collector;
      Value  : Flyology_RDF.Quads.Quad;
      Span   : Flyology_RDF.Turtle_Parsers.Source_Span);

   overriding procedure On_Diagnostic
     (Target : in out Collector;
      Value  : Flyology_RDF.Turtle_Parsers.Parse_Diagnostic);

   procedure On_Quad
     (Target : in out Collector;
      Value  : Flyology_RDF.Quads.Quad;
      Span   : Flyology_RDF.Turtle_Parsers.Source_Span)
   is
      pragma Unreferenced (Span);
   begin
      Flyology_RDF.Datasets.Insert (Target.Data, Value);
   end On_Quad;

   procedure On_Diagnostic
     (Target : in out Collector;
      Value  : Flyology_RDF.Turtle_Parsers.Parse_Diagnostic)
   is
      pragma Unreferenced (Value);
   begin
      Target.Failed := True;
   end On_Diagnostic;

   procedure Load_Turtle
     (Document : String;
      Base_IRI : String;
      Into     : out Flyology_RDF.Datasets.Dataset;
      Ok       : out Boolean)
   is
      Sink   : Collector;
      Parser : Flyology_RDF.Turtle_Parsers.Parser :=
        Flyology_RDF.Turtle_Parsers.Create
          (Source_Name => "document",
           Base_IRI    => Base_IRI,
           Syntax      => Flyology_RDF.Turtle_Parsers.Turtle_Syntax);
   begin
      Flyology_RDF.Turtle_Parsers.Feed (Parser, Document, Sink);
      Ok := Flyology_RDF.Turtle_Parsers.Finish (Parser, Sink)
              = Flyology_RDF.Turtle_Parsers.Parse_Succeeded
            and then not Sink.Failed;
      Into := Sink.Data;
   end Load_Turtle;

end SHACL_Ada.Rdf;
