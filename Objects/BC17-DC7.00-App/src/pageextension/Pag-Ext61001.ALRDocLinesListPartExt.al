pageextension 61001 "ALR Doc Lines ListPart Ext." extends "CDC Document Lines ListPart"
{
    actions
    {
        addafter(Line)
        {
            group(AdvancedLineRecognition)
            {
                Caption = 'Adv. line recognition';
                Image = SetupLines;
                action(SearchByLinkedField)
                {
                    ApplicationArea = All;
                    Caption = 'Find value by linked field';
                    Description = 'Das ist eine Beschreibung';
                    Image = Link;
                    Promoted = true;
                    PromotedCategory = Process;
                    ToolTip = 'The desired field is found via a fixed offset (distance) from another field.';

                    trigger OnAction()
                    var
                        AdvLineRecognitionMgt: Codeunit "Adv. Line Recognition Mgt.";
                    begin
                        AdvLineRecognitionMgt.SetToAnchorLinkedField(Rec);
                    end;
                }
                action(SearchByColumnHeading)
                {
                    ApplicationArea = All;
                    Caption = 'Find value by column heading';
                    Image = "Table";
                    Promoted = true;
                    ToolTip = 'The desired field is searched for using a previously trained column heading in the range of the current position.';

                    trigger OnAction()
                    var
                        AdvLineRecognitionMgt: Codeunit "Adv. Line Recognition Mgt.";
                    begin
                        AdvLineRecognitionMgt.SetToFieldSearchWithColumnHeding(Rec);
                    end;
                }
                action(SearchByCaption)
                {
                    ApplicationArea = All;
                    Caption = 'Find value by caption';
                    Image = Find;
                    Promoted = true;
                    ToolTip = 'The desired field is searched for using a previously trained search text/caption in the area of the current position.';

                    trigger OnAction()
                    var
                        AdvLineRecognitionMgt: Codeunit "Adv. Line Recognition Mgt.";
                    begin
                        AdvLineRecognitionMgt.SetToFieldSearchWithCaption(Rec);
                    end;
                }
                action(ResetFieldToDefault)
                {
                    ApplicationArea = All;
                    Caption = 'Reset field';
                    Image = ResetStatus;
                    ToolTip = 'The advanced line recognition settings are reset for the desired field.';

                    trigger OnAction()
                    var
                        AdvLineRecognitionMgt: Codeunit "Adv. Line Recognition Mgt.";
                    begin
                        AdvLineRecognitionMgt.ResetFieldFromMenu(Rec);
                    end;
                }
                action(ShowVersionNo)
                {
                    ApplicationArea = All;
                    Caption = 'Version';
                    Image = Info;
                    ToolTip = 'Displays the currently used version of the advanced line detection.';

                    trigger OnAction()
                    var
                        AdvLineRecognitionMgt: Codeunit "Adv. Line Recognition Mgt.";
                        YouAreUsingALRVersion: Label 'You are using version %1 of the advanced line recognition.';
                    begin
                        Message(YouAreUsingALRVersion, AdvLineRecognitionMgt.ShowVersionNo);
                    end;
                }
            }
        }
    }
}

