pageextension 61006 "ALR Temp. Config Subpage" extends "CDC Continia Config. Subpage"
{
    ContextSensitiveHelpPage = 'assisted-setup-guide';
    layout
    {
        addbefore(Include)
        {
            field(TemplateName; TemplateName)
            {
                Caption = 'Template Name (Type)';
                ApplicationArea = All;
                Editable = false;
                ToolTip = 'Specifies the record being imported or exported. Expand to view the subordinate records.';
            }
        }
    }

    // actions
    // {
    //     addlast(Processing)
    //     {
    //         action(IncludeAll)
    //         {
    //             ApplicationArea = All;
    //             Caption = 'Include all';
    //             Description = 'Toogles the configuration selection';
    //             Image = AllLines;

    //             ToolTip = 'Open master template of current selected Document';

    //             trigger OnAction()
    //             var
    //                 TemplateHelper: Codeunit "ALR Template Helper";
    //             begin
    //                 ToggleAll(true);
    //                 CurrPage.Update(false);
    //             end;
    //         }
    //         action(ExcludeAll)
    //         {
    //             ApplicationArea = All;
    //             Caption = 'Exclude all';
    //             Description = 'Excludes all configuration selection';
    //             Image = Line;

    //             ToolTip = 'Open master template of current selected Document';

    //             trigger OnAction()
    //             var
    //                 TemplateHelper: Codeunit "ALR Template Helper";
    //             begin
    //                 ToggleAll(false);

    //                 CurrPage.Update(false);
    //             end;
    //         }
    //     }
    //}

    var
        TemplateName: Text;

    trigger OnAfterGetRecord()
    var
        Template: Record "CDC Template";
    begin
        Clear(TemplateName);
        if Rec."Table No" = 6085579 then
            if Template.Get(Rec.Code) then begin
                Rec."Record Name" := Rec."Record Name";
                IF Template."Source Record No." <> '' THEN
                    Rec."Record Name" += STRSUBSTNO(' (%1)', Template."Source Record No.");

                TemplateName := Template.Description + STRSUBSTNO(' (%1)', Template."Data Type");
            end;
    end;

    // local procedure ToggleAll(Include: Boolean)
    // begin
    //     if Rec.FindFirst() then
    //         repeat
    //             Rec.Include := Include;
    //             Rec.Modify();
    //         until Rec.Next() = 0;
    // end;
}