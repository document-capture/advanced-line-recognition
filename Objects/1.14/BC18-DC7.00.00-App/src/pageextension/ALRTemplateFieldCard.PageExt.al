pageextension 61000 "ALR Template Field Card" extends "CDC Template Field Card"
{
    ContextSensitiveHelpPage = 'field-description';
    layout
    {
        addafter(Purchase)
        {
            group(ALR)
            {
                Caption = 'Advanced Line Recognition';
                field("ALRAdvanced Line Recognition Type"; Rec."Advanced Line Recognition Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies how the field value is to be found. With Standard, the field is searched for using the standard line recognition.';
                    trigger OnValidate()
                    begin
                        UpdateALRFields();
                    end;
                }
                group(ALRLinkedFieldGroup)
                {
                    Visible = IsLinkedFieldSearch;
                    ShowCaption = false;
                    field("ALRLinked Field"; Rec."Linked Field")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Specifies the source field used to calculate the field value via distances/offsets.';
                    }
                }
                field(ALRSorting; Rec.Sorting)
                {
                    ApplicationArea = All;
                    Importance = Additional;
                    ToolTip = 'Specifies the position of the sequence in which the field is processed.';
                }

                group(ALRCaptionBasedFieldGroup)
                {
                    Visible = ShowPositionDependendFields;
                    ShowCaption = false;
                    field("ALRField value Position"; Rec."Field value Position")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Specifies whether the searched field is searched above or below the line in which the values of the standard line recognition were found.';
                    }
                    field("ALRField value search direction"; Rec."Field value search direction")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Specifies the search direction from the standard line that is used to find the field value.';

                    }
                }
                group(ALRNoValueFound)
                {
                    Caption = 'When value is empty';
                    field("ALRCopy Value from Previous Value"; Rec."Copy Value from Previous Value")
                    {
                        ApplicationArea = All;
                        ToolTip = 'If the value of the current field is not found, the value is copied to the current line from the same field from the previous line.';
                    }
                    field("ALRReplacement Header Field"; Rec."Replacement Field Type")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Specifies if the selected field is a header or line field (Default = line)';
                    }
                    field("ALRReplacement Line Field"; Rec."Replacement Field")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Specifies the line field whose content will be used as value if the value of the current field cannot be found.';
                    }
                }

                group(ALROffsets)
                {
                    Caption = 'Offsets';
                    field("ALROffset Top"; Rec."Offset Top")
                    {
                        ApplicationArea = All;
                        Importance = Additional;
                        ToolTip = 'Specifies the distance to the top.';
                    }
                    field("ALROffset Bottom"; Rec."Offset Bottom")
                    {
                        ApplicationArea = All;
                        Importance = Additional;
                        ToolTip = 'Specifies the distance to the bottom.';
                    }
                    field("ALROffset Left"; Rec."Offset Left")
                    {
                        ApplicationArea = All;
                        Importance = Additional;
                        ToolTip = 'Specifies the distance to the left.';
                    }
                    field("ALROffset Right"; Rec."Offset Right")
                    {
                        ApplicationArea = All;
                        Importance = Additional;
                        ToolTip = 'Specifies the distance to the right.';
                    }
                    field("ALR Value Caption Offset X"; Rec."ALR Value Caption Offset X")
                    {
                        ApplicationArea = All;
                        Importance = Additional;
                        ToolTip = 'Specifies the distance to the search text/caption on the X axis.';
                    }
                    field("ALR Value Caption Offset Y"; Rec."ALR Value Caption Offset Y")
                    {
                        ApplicationArea = All;
                        Importance = Additional;
                        ToolTip = 'Specifies the distance to the search text/caption on the Y axis.';
                    }
                    field("ALR Typical Value Field Width"; Rec."ALR Typical Value Field Width")
                    {
                        ApplicationArea = All;
                        Importance = Additional;
                        ToolTip = 'Specifies the expected field width of the field.';
                    }
                }
                field("Data version"; Rec."Data version")
                {
                    ApplicationArea = All;
                    Importance = Additional;
                    Visible = false;
                    ToolTip = 'Displays the data version of the current field record.';
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        UpdateALRFields();
        CurrPage.Update(false);
    end;

    procedure UpdateALRFields()
    begin
        IsLinkedFieldSearch := Rec."Advanced Line Recognition Type" = Rec."Advanced Line Recognition Type"::LinkedToAnchorField;
        ShowPositionDependendFields := (Rec."Advanced Line Recognition Type" in [Rec."Advanced Line Recognition Type"::FindFieldByColumnHeading, Rec."Advanced Line Recognition Type"::FindFieldByCaptionInPosition]);
    end;


    var
        [InDataSet]
        IsLinkedFieldSearch: boolean;
        [InDataSet]
        ShowPositionDependendFields: Boolean;
}