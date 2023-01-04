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

    var
        TemplateName: Text;

    trigger OnAfterGetRecord()
    var
        CDCTemplate: Record "CDC Template";
        SourceRecLbl: Label ' (%1)', Locked = true;
        TemplateDataTypeLbl: Label ' (%1)', Locked = true;
    begin
        Clear(TemplateName);
        if Rec."Table No" = 6085579 then
            if CDCTemplate.Get(Rec.Code) then begin
                Rec."Record Name" := Rec."Record Name";
                IF CDCTemplate."Source Record No." <> '' THEN
                    Rec."Record Name" += STRSUBSTNO(SourceRecLbl, CDCTemplate."Source Record No.");

                TemplateName := CDCTemplate.Description + STRSUBSTNO(TemplateDataTypeLbl, CDCTemplate."Data Type");
            end;
    end;
}