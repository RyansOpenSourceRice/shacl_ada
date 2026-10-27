--  SPDX-License-Identifier: Apache-2.0

package body SHACL_Ada.Shapes with SPARK_Mode is

   function Find (Table : Shape_Table; Node : Terms.Term) return Natural is
      use type Terms.Term;
   begin
      for Index in 1 .. Table.Count loop
         if Table.List (Index).Node = Node then
            return Index;
         end if;
      end loop;
      return 0;
   end Find;

   procedure Add_Path_Node
      (Table : in out Shape_Table; Node : Path_Node; Index : out Natural)
   is
   begin
      if Table.Path_Count >= Max_Path_Nodes then
         Index := 0;
      else
         Table.Path_Count := Table.Path_Count + 1;
         Table.Paths (Table.Path_Count) := Node;
         Index := Table.Path_Count;
      end if;
   end Add_Path_Node;

   function Term_Of (Table : Shape_Table; Ref : Target_Ref) return Terms.Term is
     (Table.List (Ref.Shape).Targets (Ref.Slot).Value);

   --  Tag each member with its distinct-term ordinal (first-appearance
   --  order) and record the distinct keys. Every member lands in
   --  exactly one group, so Member counts are preserved.
   procedure Tag_One_Kind
     (Table        : Shape_Table;
      Members      : Target_Ref_Array;
      Member_Count : Natural;
      Tags         : in out Group_Tag_Array;
      Keys         : in out Target_Ref_Array;
      Key_Count    : in out Natural)
    with Pre  => Member_Count <= Max_Index_Entries,
         Post => Key_Count <= Member_Count
    is
       use type Terms.Term;
       Found : Natural range 0 .. Max_Index_Entries := 0;
    begin
       Key_Count := 0;
       for I in 1 .. Member_Count loop
          pragma Loop_Invariant (Key_Count < I);
          pragma Loop_Invariant (Key_Count <= Member_Count);
          pragma Loop_Invariant (Found <= Key_Count);
         Found := 0;
         for D in 1 .. Key_Count loop
            pragma Loop_Invariant (Found <= D - 1);
            if Term_Of (Table, Members (I)) = Term_Of (Table, Keys (D)) then
               Found := D;
               exit;
            end if;
         end loop;
         if Found = 0 then
            Key_Count := Key_Count + 1;
            Keys (Key_Count) := Members (I);
            Found := Key_Count;
         end if;
         Tags (I) := Found;
      end loop;
   end Tag_One_Kind;

   procedure Finalize_Index (Table : in out Shape_Table) is
      use type Terms.Term;

      Seen : Natural := 0;

      procedure Note_Target (Shape_Idx : Shape_Index; Slot : Target_Position) is
         Ref : constant Target_Ref := (Shape => Shape_Idx, Slot => Slot);
      begin
         case Table.List (Shape_Idx).Targets (Slot).Kind is
            when Target_Node =>
               Table.Node_Count := Table.Node_Count + 1;
               Table.Nodes (Table.Node_Count) := Ref;
            when Target_Class =>
               Table.Class_Member_Count := Table.Class_Member_Count + 1;
               Table.Class_Members (Table.Class_Member_Count) := Ref;
            when Target_Subjects_Of =>
               Table.Subject_Member_Count := Table.Subject_Member_Count + 1;
               Table.Subject_Members (Table.Subject_Member_Count) := Ref;
            when Target_Objects_Of =>
               Table.Object_Member_Count := Table.Object_Member_Count + 1;
               Table.Object_Members (Table.Object_Member_Count) := Ref;
         end case;
      end Note_Target;

       --  Group one kind's members into locals, then copy back.
       --  Locals keep the writable arguments disjoint from the table
       --  the tagger also reads (SPARK RM 6.4.2: no overlapping
       --  writable arguments), so no nested-procedure aliasing arises.
       procedure Tag_Kind (Kind : Target_Kind) is
          Tags : Group_Tag_Array := (others => 0);
          Keys : Target_Ref_Array := (others => <>);
          KC   : Natural := 0;
       begin
          case Kind is
             when Target_Node =>
                null;  --  explicit nodes need no grouping
             when Target_Class =>
                Tag_One_Kind
                  (Table, Table.Class_Members, Table.Class_Member_Count,
                   Tags, Keys, KC);
                Table.Class_Member_Groups := Tags;
                Table.Class_Keys := Keys;
                Table.Class_Key_Count := KC;
             when Target_Subjects_Of =>
                Tag_One_Kind
                  (Table, Table.Subject_Members, Table.Subject_Member_Count,
                   Tags, Keys, KC);
                Table.Subject_Member_Groups := Tags;
                Table.Subject_Keys := Keys;
                Table.Subject_Key_Count := KC;
             when Target_Objects_Of =>
                Tag_One_Kind
                  (Table, Table.Object_Members, Table.Object_Member_Count,
                   Tags, Keys, KC);
                Table.Object_Member_Groups := Tags;
                Table.Object_Keys := Keys;
                Table.Object_Key_Count := KC;
          end case;
       end Tag_Kind;

    begin
      Table.Indexed := False;
      Table.Node_Count := 0;
      Table.Class_Member_Count := 0;
      Table.Class_Key_Count := 0;
      Table.Subject_Member_Count := 0;
      Table.Subject_Key_Count := 0;
      Table.Object_Member_Count := 0;
      Table.Object_Key_Count := 0;

      --  Pass A: arrival-order members per kind. Deactivated shapes
      --  contribute nothing. Seen counts processed targets: at most
      --  Max_Shapes * Max_Targets_Per_Shape, so every list fits.
      for S in 1 .. Table.Count loop
         pragma Loop_Invariant (Seen <= (S - 1) * Max_Targets_Per_Shape);
         pragma Loop_Invariant (Table.Node_Count <= Seen);
         pragma Loop_Invariant (Table.Class_Member_Count <= Seen);
         pragma Loop_Invariant (Table.Subject_Member_Count <= Seen);
         pragma Loop_Invariant (Table.Object_Member_Count <= Seen);
         if not Table.List (S).Deactivated then
            for T in 1 .. Table.List (S).Target_Count loop
               pragma Loop_Invariant (Seen <= (S - 1) * Max_Targets_Per_Shape + (T - 1));
               pragma Loop_Invariant (Table.Node_Count <= Seen);
               pragma Loop_Invariant (Table.Class_Member_Count <= Seen);
               pragma Loop_Invariant (Table.Subject_Member_Count <= Seen);
               pragma Loop_Invariant (Table.Object_Member_Count <= Seen);
               Note_Target (S, T);
               Seen := Seen + 1;
            end loop;
         end if;
      end loop;

      --  Pass B: group tags per kind (first appearance order).
      Tag_Kind (Target_Class);
      Tag_Kind (Target_Subjects_Of);
      Tag_Kind (Target_Objects_Of);

      Table.Indexed := True;
   end Finalize_Index;

end SHACL_Ada.Shapes;
