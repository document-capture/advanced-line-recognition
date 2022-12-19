pageextension 61003 "ALR DocList Ext" extends "CDC Document List With Image"
{
    actions
    {
        addafter("Remove Template Field")
        {
            action(MasterTemplate)
            {
                ApplicationArea = All;
                Caption = 'Master Template';
                Description = 'Open master template of current selected Document';
                Image = Open;
                Promoted = true;
                PromotedCategory = Category6;
                ToolTip = 'Open master template of current selected Document';

                trigger OnAction()
                begin
                    TemplateHelper.OpenMasterTemplate(Rec, IsXMLTemplate);
                end;
            }

            action(IdentificationTemplate)
            {
                ApplicationArea = All;
                Caption = 'Ident. Template';
                Description = 'Open identification template of current selected Document';
                Image = Find;
                Promoted = true;
                PromotedCategory = Category6;
                ToolTip = 'Open identification template of current selected Document';

                trigger OnAction()
                begin
                    TemplateHelper.OpenIdentificationTemplate(Rec, IsXMLTemplate);

                end;
            }
            action(CopySettingToMaster)
            {
                ApplicationArea = All;
                Caption = 'Copy field config to Master';
                Description = 'Copies the documents XML configuration to the Master template';
                Image = Copy;
                Promoted = true;
                PromotedCategory = Category6;
                ToolTip = 'Copies the documents XML configuration to the Master template';
                Visible = IsXMLTemplate;

                trigger OnAction()
                var

                begin
                    if not IsXMLTemplate then
                        exit;

                    TemplateHelper.CopyFieldSettingsToMasterTemplate(Rec);
                end;
            }
        }
    }

    var
        [InDataSet]
        IsXMLTemplate: Boolean;
        TemplateHelper: Codeunit "ALR Template Helper";

    trigger OnAfterGetCurrRecord()
    begin
        IsXMLTemplate := Rec."File Type" = Rec."File Type"::XML;
    end;
}