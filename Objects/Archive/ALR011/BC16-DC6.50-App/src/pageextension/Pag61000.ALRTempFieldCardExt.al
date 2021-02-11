pageextension 61000 "ALR Temp. Field Card Ext." extends "CDC Template Field Card"
{
    layout
    {
        addafter(Purchase)
        {
            group(ALR)
            {
                Caption = 'Advanced Line Recognition';

                field("Advanced Line Recognition Type"; "Advanced Line Recognition Type")
                {
                    ApplicationArea = All;
                    Caption = 'Erw. Zeilenerkennung Art';
                }
                field(Sorting; Sorting)
                {
                    ApplicationArea = All;
                    Caption = 'Sortierung';
                }
                field("Anchor Field"; "Anchor Field")
                {
                    ApplicationArea = All;
                    Caption = 'Ankerfeld';
                }
                field("Field Position"; "Field Position")
                {
                    ApplicationArea = All;
                    Caption = 'Feldposition';
                }
                field("Substitution Field"; "Substitution Field")
                {
                    ApplicationArea = All;
                    Caption = 'Ersatzfeld';
                }
                field("Get Value from Previous Value"; "Get Value from Previous Value")
                {
                    ApplicationArea = All;
                    Caption = 'Copy from prev. value';
                }
                field("Offset Top"; "Offset Top")
                {
                    ApplicationArea = All;
                    Caption = 'Offset top';
                }
                field("Offset Bottom"; "Offset Bottom")
                {
                    ApplicationArea = All;
                    Caption = 'Offset Bottom';
                }
                field("Offset Left"; "Offset Left")
                {
                    ApplicationArea = All;
                    Caption = 'Offset Left';
                }
                field("Offset Right"; "Offset Right")
                {
                    ApplicationArea = All;
                    Caption = 'Offset Right';
                }
                field("ALR Value Caption Offset X"; "ALR Value Caption Offset X")
                {
                    ApplicationArea = All;
                    Caption = 'ALR Value Caption Offset X';
                    Importance = Additional;
                }
                field("ALR Value Caption Offset Y"; "ALR Value Caption Offset Y")
                {
                    ApplicationArea = All;
                    Caption = 'ALR Value Caption Offset Y';
                    Importance = Additional;
                }
                field("ALR Typical Value Field Width"; "ALR Typical Value Field Width")
                {
                    ApplicationArea = All;
                    Caption = 'ALR Typical Value Field Width';
                    Importance = Additional;
                }
            }
        }
    }
}