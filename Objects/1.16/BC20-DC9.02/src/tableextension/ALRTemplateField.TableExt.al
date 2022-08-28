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
            Caption = 'Replacement field type';
            DataClassification = CustomerContent;
            OptionCaption = 'Header,Line';
            OptionMembers = Header,Line;
            trigger OnValidate()
            begin
                if xRec."Replacement Field Type" <> Rec."Replacement Field Type" then
                    clear(rec."Replacement Field");
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
    // trigger OnModify()
    // var
    //     InstallMgt: Codeunit "ALR Install Management";
    // begin
    //     Rec."Data version" := InstallMgt.GetDataVersion();

    // end;
}