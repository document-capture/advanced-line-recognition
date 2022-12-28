pageextension 61000 "ALR Template Field Card" extends "CDC Template Field Card"
{
    ContextSensitiveHelpPage = 'template-field-card';
    layout
    {
        addbefore("Advanced Recognition Settings")
        {
            group(CopyValueFrom)
            {
                Visible = not IsLineField;
                Caption = 'Copy value from';

                field(CopySourceField; CopySourceField)
                {
                    ApplicationArea = All;
                    CaptionClass = Rec.GetSourceFieldCaption();
                    ToolTip = 'Specifies the field in the source table whose value is to be used as field value.';

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        DocCat: Record "CDC Document Category";
                        Template: Record "CDC Template";
                    begin
                        Template.GET(Rec."Template No.");
                        DocCat.GET(Template."Category Code");
                        exit(RecIDMgt.LookupField(Text, DocCat."Source Table No.", FALSE));
                    end;

                    trigger OnValidate()
                    var
                        Template: Record "CDC Template";
                        DocCat: Record "CDC Document Category";
                    begin
                        Template.GET(Rec."Template No.");
                        DocCat.GET(Template."Category Code");
                        Rec.VALIDATE("Get value from source field", RecIdMgt_GetFieldID(DocCat."Source Table No.", CopySourceField));
                        CurrPage.UPDATE(TRUE);
                    end;
                }
            }
        }

        addafter(Purchase)
        {
            group(ALR)
            {
                Caption = 'Advanced Line Recognition';
                Visible = IsLineField;

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
                    field("Empty value handling"; Rec."Empty value handling")
                    {
                        ApplicationArea = All;
                        ToolTip = 'If the value of the current field is not found, the value is copied to the current line from the same field from the previous line.';
                        trigger OnValidate()
                        begin
                            UpdateALRFields();
                        end;
                    }

                    group(ReplacementTypeGroup)
                    {
                        ShowCaption = false;
                        Visible = IsFieldReplacement;

                        field("ALRReplacement Line Field"; Rec."Replacement Field")
                        {
                            ApplicationArea = All;
                            ToolTip = 'Specifies the line field whose content will be used as value if the value of the current field cannot be found.';
                            trigger OnValidate()
                            begin
                                UpdateALRFields();
                            end;
                        }

                    }
                    group(FixedReplacementGroup)
                    {
                        ShowCaption = false;
                        Visible = IsFixedReplacementValue;

                        field(ALRFixedReplacementValue; Rec."Fixed Replacement Value")
                        {
                            ApplicationArea = All;
                            ToolTip = 'Specifies the fixed value that will be used as value if the value of the current field cannot be found.';
                            trigger OnValidate()
                            begin
                                UpdateALRFields();
                            end;
                        }
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

            }

        }

        addafter(General)
        {
            group(TextManipulation)
            {
                Caption = 'Text manipulations';
                Visible = IsTextField;

                group(DelChr)
                {
                    Caption = 'Delete characters';

                    field("Enable DelChr"; Rec."Enable DelChr")
                    {
                        ApplicationArea = All;
                        Caption = 'Delete characters from value';
                        ToolTip = 'If enabled the system can delete characters from the value.';
                        trigger OnValidate()
                        begin
                            Rec.TestField("Data Type", Rec."Data Type"::Text);
                            UpdateALRFields();
                        end;
                    }
                    group(AlrDelChr)
                    {
                        ShowCaption = false;
                        Visible = DelChrEnabled;

                        field("Pos. of characters"; Rec."Pos. of characters")
                        {
                            ApplicationArea = All;
                            ToolTip = 'Specifies the position where the original string is to be shortened.';
                        }

                        field("Characters to delete"; Rec."Characters to delete")
                        {
                            ApplicationArea = All;
                            ToolTip = 'Specifies the character or string to be removed. The default value is the space character.';
                        }
                    }
                }
                group(CopyStr)
                {
                    Caption = 'Extract string';

                    field("Extract string by CopyStr"; Rec."Extract string by CopyStr")
                    {
                        ApplicationArea = All;
                        Caption = 'Extract string from value';
                        ToolTip = 'Returns a part of the recognized value. It starts at "Position" and has a specified length.';

                        trigger OnValidate()
                        begin
                            Rec.TestField("Data Type", Rec."Data Type"::Text);
                            UpdateALRFields();
                        end;
                    }
                    group(CopyStrSetup)
                    {
                        ShowCaption = false;
                        Visible = CopyStrEnabled;

                        field("CopyStr Pos"; Rec."CopyStr Pos")
                        {
                            ApplicationArea = All;
                            ToolTip = 'Specifies the start position of the string that has to be extracted.';
                        }
                        field("CopyStr Length"; Rec."CopyStr Length")
                        {
                            ApplicationArea = All;
                            ToolTip = 'Specifies the length of the string that has to be extracted. If the length is omitted, all characters up to the end of the string are used.';
                        }
                    }
                }
            }

        }
    }
    actions
    {
        addafter(Codeunits)
        {
            action(MasterTemplateField)
            {
                ApplicationArea = All;
                Caption = 'Master Template Field';
                Description = 'Open master template of current selected Document';
                Image = Open;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Open master template of current selected Document';
                Visible = IsNormalField;

                trigger OnAction()
                var
                    TemplateHelper: Codeunit "ALR Template Helper";
                begin
                    TemplateHelper.OpenMasterTemplateField(Rec);
                end;
            }
        }
    }



    trigger OnAfterGetCurrRecord()
    begin
        UpdateALRFields();
    end;


    trigger OnAfterGetRecord()
    begin
        UpdateALRFields();
    end;


    procedure UpdateALRFields()
    var
        DocCat: Record "CDC Document Category";
        Template: Record "CDC Template";
    begin
        IsLinkedFieldSearch := Rec."Advanced Line Recognition Type" = Rec."Advanced Line Recognition Type"::LinkedToAnchorField;
        ShowPositionDependendFields := (Rec."Advanced Line Recognition Type" in [Rec."Advanced Line Recognition Type"::FindFieldByColumnHeading, Rec."Advanced Line Recognition Type"::FindFieldByCaptionInPosition]);
        IsLineField := Rec.Type = Rec.Type::Line;
        CopyStrEnabled := Rec."Extract string by CopyStr";
        DelChrEnabled := Rec."Enable DelChr";
        IsTextField := Rec."Data Type" = Rec."Data Type"::Text;
        IsFixedReplacementValue := (Rec."Empty value handling" = Rec."Empty value handling"::FixedValue);
        IsFieldReplacement := (Rec."Empty value handling" = Rec."Empty value handling"::CopyHeaderFieldValue) or (Rec."Empty value handling" = Rec."Empty value handling"::CopyLineFieldValue);
        IsCopyFromPrevField := (Rec."Empty value handling" = Rec."Empty value handling"::CopyPrevLineValue);
        if Template.Get(Rec."Template No.") then
            if DocCat.Get(Template."Category Code") then
                CopySourceField := RecIDMgt.GetFieldCaption(DocCat."Source Table No.", Rec."Get value from source field");

        IsNormalField := (Template.Type = Template.Type::" ");
    end;

    internal procedure RecIdMgt_GetFieldID(TableNo: Integer; Text: Text[250]) FieldNo: Integer
    var
        "Field": Record "Field";
    begin
        IF NOT EVALUATE(FieldNo, Text) THEN BEGIN
            Field.SETRANGE(TableNo, TableNo);
            Field.SETRANGE(Enabled, TRUE);
            Field.SETRANGE("Field Caption", Text);
            IF Field.FINDFIRST THEN
                EXIT(Field."No.");
        END;
    end;

    var
        [InDataSet]
        IsLinkedFieldSearch: Boolean;
        [InDataSet]
        ShowPositionDependendFields: Boolean;
        [InDataSet]
        IsLineField: Boolean;
        [InDataSet]
        IsTextField: Boolean;
        [InDataSet]
        CopyStrEnabled: Boolean;
        [InDataset]
        DelChrEnabled: Boolean;
        [InDataset]
        IsFixedReplacementValue: Boolean;
        [InDataset]
        IsFieldReplacement: Boolean;
        [InDataSet]
        IsCopyFromPrevField: Boolean;
        [InDataSet]
        IsNormalField: Boolean;
        CopySourceField: Text[250];
        RecIDMgt: Codeunit "CDC Record ID Mgt.";
}