pageextension 61001 "ALR Doc Lines ListPart Ext." extends "CDC Document Lines ListPart"
{
    layout
    {
        // Add changes to page layout here
    }

    actions
    {
        addafter(Line)
        {
            group("Adv. line recognition")
            {
                Caption = 'Adv. line recognition';
                Image = SetupLines;
                action("Link value to existing value")
                {
                    ApplicationArea = All;
                    Caption = 'Link value to existing value';
                    Image = Link;
                    Promoted = true;
                    PromotedCategory = Process;

                    trigger OnAction()
                    var
                        AdvLineRecognitionMgt: Codeunit "ALR Adv. Line Recognition Mgt.";
                    begin
                        AdvLineRecognitionMgt.SetToAnchorLinkedField(Rec);
                    end;
                }
                action("Find value by column heading")
                {
                    ApplicationArea = All;
                    Caption = 'Find value by column heading';
                    Image = SelectField;
                    Promoted = true;

                    trigger OnAction()
                    var
                        AdvLineRecognitionMgt: Codeunit "ALR Adv. Line Recognition Mgt.";
                    begin
                        AdvLineRecognitionMgt.SetToFieldSearchWithColumnHeding(Rec);
                    end;
                }
                action("Find value by caption")
                {
                    ApplicationArea = All;
                    Caption = 'Find value by caption';
                    Image = Find;
                    Promoted = true;

                    trigger OnAction()
                    var
                        AdvLineRecognitionMgt: Codeunit "ALR Adv. Line Recognition Mgt.";
                    begin
                        AdvLineRecognitionMgt.SetToFieldSearchWithCaption(Rec);
                    end;
                }
                separator(Separator1000000015)
                {
                }
                action("Reset field to default")
                {
                    ApplicationArea = All;
                    Caption = 'Reset field to default';
                    Image = ResetStatus;

                    trigger OnAction()
                    var
                        AdvLineRecognitionMgt: Codeunit "ALR Adv. Line Recognition Mgt.";
                    begin
                        AdvLineRecognitionMgt.ResetFieldFromMenu(Rec);
                    end;
                }
            }
        }
    }
}