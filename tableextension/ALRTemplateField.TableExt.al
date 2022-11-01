#pragma warning  disable AA0072
tableextension 70000 "ALR Template Field" extends "CDC Template Field"
{
    fields
    {
        field(70001; "Replacement Field"; Code[20])
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
        field(70002; "Linked Field"; Code[20])
        {
            Caption = 'Linked to field';
            DataClassification = CustomerContent;
            TableRelation = "CDC Template Field".Code WHERE("Template No." = FIELD("Template No."),
                                                             Type = CONST(Line));
        }
        field(70003; Sorting; Integer)
        {
            Caption = 'Sorting', Comment = 'Position in the sort order in which the field will be processed', Locked = false, MaxLength = 999;
            DataClassification = CustomerContent;
        }
        field(70004; "Field value position"; Option)
        {
            Caption = 'Value position', Comment = 'Defines if the value should be searched above or below the standard line.', Locked = false, MaxLength = 999;
            DataClassification = CustomerContent;
            OptionCaption = ' ,Above standard line,Below standard line';
            OptionMembers = " ",AboveStandardLine,BelowStandardLine;
        }
        field(70005; "Field value search direction"; Option)
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

        field(70006; "Replacement Field Type"; Option)
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
        field(70007; "Copy Value from Previous Value"; Boolean)
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

        field(70011; "Advanced Line Recognition Type"; Option)
        {
            Caption = 'Advanced Line Recognition Type';
            DataClassification = CustomerContent;
            OptionCaption = 'Standard,Anchor linked field,Field search with caption,Field search with column heading';
            OptionMembers = Default,LinkedToAnchorField,FindFieldByCaptionInPosition,FindFieldByColumnHeading;
        }
        field(70012; "Offset Top"; Integer)
        {
            Caption = 'Offset Top';
            DataClassification = CustomerContent;
        }
        field(70013; "Offset Bottom"; Integer)
        {
            Caption = 'Offset Height';
            DataClassification = CustomerContent;
        }
        field(70014; "Offset Left"; Integer)
        {
            Caption = 'Offset Left';
            DataClassification = CustomerContent;
        }
        field(70015; "Offset Right"; Integer)
        {
            Caption = 'Offset Width';
            DataClassification = CustomerContent;
        }
        field(70020; "ALR Value Caption Offset X"; Integer)
        {
            Caption = 'Caption Offset X';
            DataClassification = CustomerContent;
        }
        field(70021; "ALR Value Caption Offset Y"; Integer)
        {
            Caption = 'Caption Offset Y';
            DataClassification = CustomerContent;
        }
        field(70022; "ALR Typical Value Field Width"; Decimal)
        {
            Caption = 'Field Width';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
    }
    // trigger OnModify()
    // var
    //     InstallMgt: Codeunit "ALR Install Management";
    // begin
    //     Rec."Data version" := InstallMgt.GetDataVersion();

    // end;
}