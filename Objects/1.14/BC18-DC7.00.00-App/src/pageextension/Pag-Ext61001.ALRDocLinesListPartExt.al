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
                        AdvLineRecognitionMgt: Codeunit "ALR Adv. Recognition Mgt.";
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
                        AdvLineRecognitionMgt: Codeunit "ALR Adv. Recognition Mgt.";
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
                        AdvLineRecognitionMgt: Codeunit "ALR Adv. Recognition Mgt.";
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
                        AdvLineRecognitionMgt: Codeunit "ALR Adv. Recognition Mgt.";
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
                        AdvLineRecognitionMgt: Codeunit "ALR Adv. Recognition Mgt.";
                    begin
                        AdvLineRecognitionMgt.ShowVersionNo;
                    end;
                }
                action(EnableFieldRecognition)
                {
                    ApplicationArea = All;
                    Caption = 'Felderkennung aktivieren';
                    Image = SelectField;
                    ToolTip = 'TODO';
                    Visible = not ShowFieldRecognition;
                    trigger OnAction()
                    var
                    begin
                        ALRMgtSI.FlipAutoFieldRecognition();
                        ShowFieldRecognition := ALRMgtSI.GetAutoFieldRecognition();
                    end;
                }
                action(DisableFieldRecognition)
                {
                    ApplicationArea = All;
                    Caption = 'Felderkennung deaktivieren';
                    Image = SelectField;
                    ToolTip = 'TODO';
                    Visible = ShowFieldRecognition;
                    trigger OnAction()
                    var
                    begin

                        ALRMgtSI.FlipAutoFieldRecognition();
                        ShowFieldRecognition := ALRMgtSI.GetAutoFieldRecognition();
                    end;
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        ShowFieldRecognition := ALRMgtSI.GetAutoFieldRecognition();
    end;


    var
        [InDataSet]
        ShowFieldRecognition: boolean;
        ALRMgtSI: Codeunit "ALR Line Management SI";

}

