pageextension 61004 "ALR Document Card" extends "CDC Document Card"
{
    ContextSensitiveHelpPage = 'document-card';
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
                    ALRTemplateHelper.OpenMasterTemplate(Rec, IsXMLTemplate);
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
                    ALRTemplateHelper.OpenIdentificationTemplate(Rec, IsXMLTemplate);

                end;
            }
            action(DocCategory)
            {
                ApplicationArea = All;
                Caption = 'Document Category';
                Description = 'Open document category card';
                Image = Category;
                Promoted = true;
                PromotedCategory = Category6;
                ToolTip = 'Open document category card';

                trigger OnAction()
                begin
                    Rec.TestField("Document Category Code");
                    ALRTemplateHelper.OpenDocumentCategoryCard(Rec."Document Category Code");
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

                    ALRTemplateHelper.CopyFieldSettingsToMasterTemplate(Rec);
                end;
            }
        }
    }
    var
        ALRTemplateHelper: Codeunit "ALR Template Helper";
        [InDataSet]
        IsXMLTemplate: Boolean;

    trigger OnAfterGetCurrRecord()
    begin
        IsXMLTemplate := Rec."File Type" = Rec."File Type"::XML;
    end;
}
