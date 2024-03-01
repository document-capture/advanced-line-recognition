tableextension 61000 "ALR Template Field" extends "CDC Template Field"
{
    fields
    {
        field(50001; "Replacement Field"; Code[20])
        {
            Caption = 'Replacement field';
            DataClassification = CustomerContent;
            TableRelation = if ("Empty value handling" = filter(CopyHeaderFieldValue))
                 "CDC Template Field".Code WHERE("Template No." = field("Template No."), Type = const(Header))
            else
            if ("Empty value handling" = filter(CopyLineFieldValue))
                 "CDC Template Field".Code WHERE("Template No." = field("Template No."), Type = const(Line));
            trigger OnValidate()
            begin
                // if Rec."Replacement Field" <> '' then
                //     Rec.Validate("Copy Value from Previous Value", false);
            end;
        }
        field(50002; "Linked Field"; Code[20])
        {
            Caption = 'Linked to field';
            DataClassification = CustomerContent;
            TableRelation = "CDC Template Field".Code WHERE("Template No." = FIELD("Template No."),
                                                             Type = CONST(Line));
        }
        field(50003; Sorting; Integer)
        {
            Caption = 'Sorting', Comment = 'Position in the sort order in which the field will be processed', Locked = false, MaxLength = 999;
            DataClassification = CustomerContent;
        }
        field(50004; "Field value position"; Option)
        {
            Caption = 'Value position', Comment = 'Defines if the value should be searched above or below the standard line.', Locked = false, MaxLength = 999;
            DataClassification = CustomerContent;
            OptionCaption = ' ,Above standard line,Below standard line';
            OptionMembers = " ",AboveStandardLine,BelowStandardLine;
        }
        field(50005; "Field value search direction"; Option)
        {
            Caption = 'Value search direction', Comment = 'Defines the search direction to find the value', Locked = false, MaxLength = 999;
            DataClassification = CustomerContent;
            OptionCaption = 'Downwards,Upwards';
            OptionMembers = Downwards,Upwards;
            trigger OnValidate()
            begin
                // Only possible for feature Search value by column heading
                TestField("Advanced Line Recognition Type", "Advanced Line Recognition Type"::FindFieldByColumnHeading);
            end;
        }

        field(50006; "Replacement Field Type"; Option)
        {
            Caption = 'Replacement type';
            DataClassification = CustomerContent;
            OptionCaption = 'Header Field,Line Field,Fixed Value';
            OptionMembers = Header,Line,FixedValue;
            ObsoleteState = Pending;
            ObsoleteReason = 'Replaced by field Empty value handling';
            trigger OnValidate()
            begin
                if xRec."Replacement Field Type" <> Rec."Replacement Field Type" then begin
                    Clear(rec."Replacement Field");
                    Clear(rec."Fixed Replacement Value");
                end

            end;
        }
        field(50007; "Copy Value from Previous Value"; Boolean)
        {
            Caption = 'Copy value from previous value';
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                if Rec."Copy Value from Previous Value" then
                    Clear(Rec."Replacement Field");
            end;
        }
        // field(50010; "Data version"; Integer)
        // {
        //     Caption = 'ALR Data version';
        //     DataClassification = CustomerContent;
        //     Editable = false;
        // }

        field(50011; "Advanced Line Recognition Type"; Option)
        {
            Caption = 'Advanced Line Recognition Type';
            DataClassification = CustomerContent;
            OptionCaption = 'Standard,Anchor linked field,Field search with caption,Field search with column heading';
            OptionMembers = Default,LinkedToAnchorField,FindFieldByCaptionInPosition,FindFieldByColumnHeading;
        }
        field(50012; "Offset Top"; Integer)
        {
            Caption = 'Offset Top';
            DataClassification = CustomerContent;
        }
        field(50013; "Offset Bottom"; Integer)
        {
            Caption = 'Offset Height';
            DataClassification = CustomerContent;
        }
        field(50014; "Offset Left"; Integer)
        {
            Caption = 'Offset Left';
            DataClassification = CustomerContent;
        }
        field(50015; "Offset Right"; Integer)
        {
            Caption = 'Offset Width';
            DataClassification = CustomerContent;
        }
        field(50020; "ALR Value Caption Offset X"; Integer)
        {
            Caption = 'Caption Offset X';
            DataClassification = CustomerContent;
        }
        field(50021; "ALR Value Caption Offset Y"; Integer)
        {
            Caption = 'Caption Offset Y';
            DataClassification = CustomerContent;
        }
        field(50022; "ALR Typical Value Field Width"; Decimal)
        {
            Caption = 'Field Width';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(61000; "Empty value handling"; enum "ALR Empty Field Value Handling")
        {
            Caption = 'Empty value handling';
            DataClassification = CustomerContent;
            InitValue = "Ignore";
            trigger OnValidate()
            begin
                if Rec."Empty value handling" <> xRec."Empty value handling" then begin
                    Clear("Replacement Field");
                    Clear("Fixed Replacement Value");
                end;
            end;
        }
        field(61001; "Fixed Replacement Value"; Text[200])
        {
            Caption = 'Fixed replacement value';
            DataClassification = CustomerContent;
        }
        field(61003; "Get value from source field"; Integer)
        {
            DataClassification = CustomerContent;
            BlankZero = true;
            Caption = 'Get value from source field';
            TableRelation = Field."No.";

            trigger OnValidate()
            var
                CDCDocumentCategory: Record "CDC Document Category";
                CDCTemplate: Record "CDC Template";
                "Field": Record "Field";
            begin
                Rec.TestField("Linked Table No.", 0);
                Rec.TestField("Linked table field number", 0);

                if ("Get value from source field" = xRec."Get value from source field") OR ("Get value from source field" = 0) then
                    exit;

                CDCTemplate.Get("Template No.");
                CDCDocumentCategory.Get(CDCTemplate."Category Code");
                CDCDocumentCategory.TestField("Source Table No.");

                Field.Get(CDCDocumentCategory."Source Table No.", "Get value from source field");
                Field.TestField(Enabled);
                Field.TestField(Class, Field.Class::Normal);
            end;
        }
        field(61004; "Linked Table No."; Integer)
        {
            BlankZero = true;
            Caption = 'Linked Table';
            DataClassification = CustomerContent;
            TableRelation = AllObj."Object ID" WHERE("Object Type" = CONST(Table));

            trigger OnValidate()
            var
                DCLogMgt: Codeunit "CDC Log Mgt.";
                RecIDMgt: Codeunit "CDC Record ID Mgt.";
            begin
                DCLogMgt.IsLogActive2("Linked Table No.", true);

                if "Linked Table No." = xRec."Linked Table No." then
                    exit;

                RecIDMgt_CheckDocValue(Type = Type::Line, Code, "Template No.", CopyStr(FIELDCAPTION("Linked Table No."), 1, 30));

                //if "Linked Table No." = 0 then begin
                RecIDMgt.DeleteTableFilter("Linked Table Filter GUID");
                Clear("Linked table field number");
                CLEAR("Linked Table Filter GUID");
                //end;


            end;
        }
        field(61005; "Linked Table Filter GUID"; Guid)
        {
            Caption = 'Source Table Filter GUID';
            DataClassification = CustomerContent;
        }
        field(61006; "No. of Linked Table Filters"; Integer)
        {
            BlankZero = true;
            CalcFormula = Count("CDC Table Filter Field" WHERE("Table Filter GUID" = FIELD("Linked Table Filter GUID")));
            Caption = 'No. of Linked Table Filters';
            Editable = false;
            FieldClass = FlowField;
        }
        field(61007; "Linked table field number"; Integer)
        {
            DataClassification = CustomerContent;
            BlankZero = true;
            Caption = 'Field from linked table';
            TableRelation = Field."No.";

            trigger OnValidate()
            var
                "Field": Record "Field";
            begin
                Rec.Testfield("Get value from source field", 0);
                Rec.TestField("Linked Table No.");

                if ("Linked table field number" = xRec."Linked table field number") OR ("Linked table field number" = 0) then
                    exit;

                Field.Get("Linked Table No.", "Linked table field number");
                Field.TestField(Enabled);
                Field.TestField(Class, Field.Class::Normal);
            end;
        }

        field(61030; "Enable DelChr"; Boolean)
        {
            Caption = 'Delete characters from string';
            DataClassification = CustomerContent;
        }
        field(61031; "Characters to delete"; Text[200])
        {
            Caption = 'Character(s) to delete';
            DataClassification = CustomerContent;
        }
        field(61032; "Pos. of characters"; Enum "ALR DelChrWhere Enum")
        {
            Caption = 'Deleted characters position';
            DataClassification = CustomerContent;
        }
        field(61033; "Extract string by CopyStr"; Boolean)
        {
            Caption = 'Extract string';
            DataClassification = CustomerContent;
        }
        field(61034; "CopyStr Pos"; Integer)
        {
            Caption = 'Start of string';
            DataClassification = CustomerContent;
            InitValue = 1;
        }

        field(61035; "CopyStr Length"; Integer)
        {
            Caption = 'Length of string';
            DataClassification = CustomerContent;
            BlankZero = true;
        }
    }

    internal procedure GetSourceFieldCaption() FieldCap: Text[250]
    var
        AllObjWithCaption: Record AllObjWithCaption;
        CDCDocumentCategory: Record "CDC Document Category";
        CDCTemplate: Record "CDC Template";
        CDCRecordIDMgt: Codeunit "CDC Record ID Mgt.";
        SourceFieldLbl: Label '%1 %2', Comment = '%1 is replaced by table name, %2 by object caption', Locked = true;
    begin
        IF CDCTemplate.GET(Rec."Template No.") THEN
            CDCDocumentCategory.GET(CDCTemplate."Category Code");

        FieldCap := StrSubstNo(SourceFieldLbl, FieldFromSourceTableNameLbl, CDCRecordIDMgt.GetObjectCaption(AllObjWithCaption."Object Type"::Table, CDCDocumentCategory."Source Table No."));
        IF FieldCap = '' THEN
            FieldCap := SourceNoFieldCaptioLbl;

    end;

    internal procedure GetLinkedFieldCaption() FieldCap: Text[250]
    var
        AllObjWithCaption: Record AllObjWithCaption;
        CDCRecordIDMgt: Codeunit "CDC Record ID Mgt.";
        LookupFieldLbl: Label '%1 %2', Comment = '%1 is replaced by table name, %2 by object caption', Locked = true;
    begin
        FieldCap := StrSubstNo(LookupFieldLbl, FieldFromSourceTableNameLbl, CDCRecordIDMgt.GetObjectCaption(AllObjWithCaption."Object Type"::Table, Rec."Linked Table No."));
        IF FieldCap = '' THEN
            FieldCap := LinkedFieldNoFieldCaptioLbl;

    end;

    local procedure RecIdMgt_CheckDocValue(IsLineField: Boolean; "Code": Code[20]; TemplNo: Code[20]; FieldCap: Text[30])
    var
        CDCDocumentValue: Record "CDC Document Value";
    begin
        CDCDocumentValue.SETRANGE(Code, Code);
        CDCDocumentValue.SETRANGE("Template No.", TemplNo);
        IF IsLineField THEN
            CDCDocumentValue.SETFILTER("Line No.", '<>%1', 0);
        CDCDocumentValue.SETFILTER("Value (Record ID Tree ID)", '<>%1', 0);
        IF NOT CDCDocumentValue.ISEMPTY THEN
            ERROR(FieldCannotChangedDueToExistingValuesLbl, FieldCap);
    end;

    internal procedure RecIdMgt_GetFirstKeyField(TableNo: Integer): Integer
    var
        [SecurityFiltering(SecurityFilter::Ignored)]
        FirstKeyRecordRef: RecordRef;
        FieldRef: FieldRef;
        KeyRef: KeyRef;
    begin
        IF TableNo = 0 THEN
            EXIT(0);

        FirstKeyRecordRef.OPEN(TableNo);
        //RecRef.SETPERMISSIONFILTER;  Not supported from NAV 2013 and forward
        IF FirstKeyRecordRef.FindFirst() THEN;
        KeyRef := FirstKeyRecordRef.KEYINDEX(1);
        FieldRef := KeyRef.FIELDINDEX(1);
        EXIT(FieldRef.NUMBER);
    end;

    var
        FieldFromSourceTableNameLbl: Label 'Field from';
        LinkedFieldNoFieldCaptioLbl: Label 'Linked Table Field';
        SourceNoFieldCaptioLbl: Label 'Source Record Field';
        FieldCannotChangedDueToExistingValuesLbl: Label '%1 cannot be changed because this field already have a value on one or more documents.', Comment = '%1 will be replace by field name';
}