pageextension 61005 "ALR Template Subpage" extends "CDC Template Subpage"
{
    ContextSensitiveHelpPage = 'template-card';

    actions
    {
        addlast(processing)
        {
            action(CopyFieldToOtherTemplate)
            {
                ApplicationArea = All;
                Caption = 'Copy Field to Template';
                Description = 'Copies the field configuration into another template';
                Image = CopyWorksheet;
                Enabled = Rec."Sort Order" <> 0;

                ToolTip = 'Open master template of current selected Document';

                trigger OnAction()
                var
                    TemplateHelper: Codeunit "ALR Template Helper";
                begin
                    TemplateHelper.CopyTemplateField(Rec);
                end;
            }
        }
    }
}