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

    internal procedure OpenDocumentCategoryCard(DocumentCategory: Code[10])
    var
        DocCat: Record "CDC Document Category";
        DocCatCard: Page "CDC Document Category Card";
    begin
        if DocCat.Get(DocumentCategory) then begin
            DocCatCard.SetRecord(DocCat);
            DocCatCard.Run();
        end
    end;

    internal procedure OpenMasterTemplateField(TemplateField: Record "CDC Template Field")
    var
        Template: Record "CDC Template";
        MasterTemplateField: Record "CDC Template Field";
        TemplateFieldCard: page "CDC Template Field Card";
    begin
        if not Template.Get(TemplateField."Template No.") then
            exit;

        Template.TestField(Type, Template.Type::" ");

        // Accept to raise an error, if master template doesn't exist anymore
        MasterTemplateField.Get(Template."Master Template No.", TemplateField.Type, TemplateField.Code);

        TemplateFieldCard.SetRecord(MasterTemplateField);
        TemplateFieldCard.Caption := 'Master Template Field Card';
        TemplateFieldCard.RunModal();
    end;

    internal procedure CopyTemplateField(SourceField: Record "CDC Template Field")
    var
        Template: Record "CDC Template";
        TargetField: Record "CDC Template Field";
        TemplateList: Page "CDC Template List";
        TemplateCard: Page "CDC Template Card";
    begin
        Template.SetCurrentKey("Category Code", "Source Record ID Tree ID");
        TemplateList.SetTableView(Template);
        TemplateList.LookupMode := true;
        if TemplateList.RunModal() = Action::LookupOK then begin
            TemplateList.GetRecord(Template);
            TargetField.Init();
            TargetField.TransferFields(SourceField, true);
            TargetField."Template No." := Template."No.";
            TargetField.Insert(true);
            if Confirm('The field has been successfully copied. Click yes to open the template card of %1 (%2)', false, Template.Description, Template."No.") then begin
                TemplateCard.SetRecord(Template);
                TemplateCard.Run();
            end;
        end;


    end;
}
