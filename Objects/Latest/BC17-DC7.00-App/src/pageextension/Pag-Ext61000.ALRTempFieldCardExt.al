pageextension 61000 "ALR Temp. Field Card Ext." extends "CDC Template Field Card"
{
    layout
    {
        addafter(Purchase)
        {
            group(ALR)
            {
                Caption = 'Advanced Line Recognition';
                field("Advanced Line Recognition Type"; Rec."Advanced Line Recognition Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies how the field value is to be found. With Standard, the field is searched for using the standard row recognition.';
                }
                field(Sorting; Rec.Sorting)
                {
                    ApplicationArea = All;
                    Importance = Additional;
                    ToolTip = 'Specifies the position of the sequence in which the field is processed.';
                }
                field("Anchor Field"; Rec."Anchor Field")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the source field used to calculate the field value via distances/offsets.';
                }
                field("Field Position"; Rec."Field Position")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the searched field is searched above or below the line in which the values of the standard line recognition were found.';
                }
                field("Substitution Field"; Rec."Substitution Field")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the line field whose content will be used as value if the value of the current field cannot be found.';
                }
                field("Get Value from Previous Value"; Rec."Get Value from Previous Value")
                {
                    ApplicationArea = All;
                    ToolTip = 'If the value of the current field is not found, the value is copied to the current line from the same field from the previous line.';
                }
                group(Offsets)
                {
                    Caption = 'Offsets';
                    field("Offset Top"; Rec."Offset Top")
                    {
                        ApplicationArea = All;
                        Importance = Additional;
                        ToolTip = 'Specifies the distance to the top.';
                    }
                    field("Offset Bottom"; Rec."Offset Bottom")
                    {
                        ApplicationArea = All;
                        Importance = Additional;
                        ToolTip = 'Specifies the distance to the bottom.';
                    }
                    field("Offset Left"; Rec."Offset Left")
                    {
                        ApplicationArea = All;
                        Importance = Additional;
                        ToolTip = 'Specifies the distance to the left.';
                    }
                    field("Offset Right"; Rec."Offset Right")
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
    }
}