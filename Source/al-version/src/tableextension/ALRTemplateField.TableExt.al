#pragma warning  disable AA0072
tableextension 61000 "ALR Template Field" extends "CDC Template Field"
{
    fields
    {
        field(50001; "Replacement Field"; Code[20])
        {
            Caption = 'Replacement field';
            DataClassification = CustomerContent;
            TableRelation = "CDC Template Field".Code WHERE("Template No." = FIELD("Template No."),
                                                          Type = Field("Replacement Field Type"));
            trigger OnValidate()
            begin
                if Rec."Replacement Field" <> '' then
                    Rec.Validate("Copy Value from Previous Value", false);

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
                Template: Record "CDC Template";
                "Field": Record "Field";
                DocCat: Record "CDC Document Category";
                RecIDMgt: Codeunit "CDC Record ID Mgt.";
            begin
                Rec.TestField("Get value from lookup", false);

                if ("Get value from source field" = xRec."Get value from source field") OR ("Get value from source field" = 0) then
                    exit;

                Template.Get("Template No.");
                DocCat.Get(Template."Category Code");
                DocCat.TestField("Source Table No.");

                Field.Get(DocCat."Source Table No.", "Get value from source field");
                Field.TestField(Enabled);
                Field.TestField(Class, Field.Class::Normal);
            end;
        }
        field(61004; "Get value from lookup"; Boolean)
        {
            DataClassification = CustomerContent;
            trigger OnValidate()
            begin
                Rec.Testfield("Get value from source field", 0);
                Rec.TestField("Data Type", Rec."Data Type"::Lookup);
                Rec.TestField("Source Table No.");
                Rec.TestField("Source Field No.");
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
        Template: Record "CDC Template";
        DocCat: Record "CDC Document Category";
        AllObjWithCaption: Record AllObjWithCaption;
        RecIDMgt: Codeunit "CDC Record ID Mgt.";
    begin
        IF Template.GET(Rec."Template No.") THEN
            DocCat.GET(Template."Category Code");

        FieldCap := StrSubstNo('%1 %2', FieldFromSourceTableNameLbl, RecIDMgt.GetObjectCaption(AllObjWithCaption."Object Type"::Table, DocCat."Source Table No."));
        IF FieldCap = '' THEN
            FieldCap := SourceNoFieldCaption;

    end;
    // trigger OnModify()
    // var
    //     InstallMgt: Codeunit "ALR Install Management";
    // begin
    //     Rec."Data version" := InstallMgt.GetDataVersion();

    // end;
    var
        SourceNoFieldCaption: Label 'Source Record Field';
        FieldFromSourceTableNameLbl: Label 'Field from';
}