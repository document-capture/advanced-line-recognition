codeunit 61007 "ALR Template Helper"
{
    internal procedure OpenMasterTemplate(Rec: Record "CDC Document"; IsXmlTemplate: Boolean)
    var
        Template: Record "CDC Template";
        TemplateCard: page "CDC Template Card";
    begin
        if IsXMLTemplate then begin
            Rec.TestField("XML Master Template No.");
            if not Template.Get(Rec."XML Master Template No.") then
                exit;
        end else begin
            Rec.TestField("Template No.");
            if not Template.Get(Rec."Template No.") then
                exit;
            if not Template.Get(Template."Master Template No.") then
                exit;
        end;

        TemplateCard.SetRecord(Template);
        TemplateCard.Run();
    end;

    internal procedure OpenIdentificationTemplate(Rec: Record "CDC Document"; IsXMLTemplate: Boolean)
    var
        Template: Record "CDC Template";
        TemplateCard: page "CDC Template Card";
    begin
        if IsXMLTemplate then begin
            Rec.TestField("XML Ident. Template No.");
            if not Template.Get(Rec."XML Ident. Template No.") then
                exit;
        end else begin
            Template.SetRange(Type, Template.Type::Identification);
            Template.SetRange("Data Type", Template."Data Type"::PDF);
            if not Template.FindFirst() then
                exit;
        end;
        TemplateCard.SetRecord(Template);
        TemplateCard.Run();
    end;

    internal procedure CopyFieldSettingsToMasterTemplate(Rec: Record "CDC Document")
    var
        Template: Record "CDC Template";
        TemplateField: Record "CDC Template Field";
        MasterField: Record "CDC Template Field";
    begin
        Rec.TestField("XML Master Template No.");
        if Template.Get(Rec."Template No.") then begin
            TemplateField.SetRange("Template No.", Rec."Template No.");
            TemplateField.SetRange("Type", Template.Type);
            TemplateField.SetFilter("XML Path", '<>%1', '');
            if TemplateField.FindSet() then
                repeat
                    if MasterField.Get(Rec."XML Master Template No.", TemplateField.Type, TemplateField.Code) then begin
                        MasterField."XML Path" := TemplateField."XML Path";
                        MasterField.Modify();
                    end;
                until TemplateField.Next() = 0;
        end;
    end;
}
