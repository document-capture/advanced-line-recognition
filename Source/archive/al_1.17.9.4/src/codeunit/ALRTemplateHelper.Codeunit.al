codeunit 61007 "ALR Template Helper"
{
    internal procedure OpenMasterTemplate(CDCDocument: Record "CDC Document"; IsXmlTemplate: Boolean)
    var
        CDCTemplate: Record "CDC Template";
        CDCCDCTemplateCard: page "CDC Template Card";
    begin
        if IsXMLTemplate then begin
            CDCDocument.TestField("XML Master Template No.");
            if not CDCTemplate.Get(CDCDocument."XML Master Template No.") then
                exit;
        end else begin
            CDCDocument.TestField("Template No.");
            if not CDCTemplate.Get(CDCDocument."Template No.") then
                exit;
            if not CDCTemplate.Get(CDCTemplate."Master Template No.") then
                exit;
        end;

        CDCCDCTemplateCard.SetRecord(CDCTemplate);
        CDCCDCTemplateCard.Run();
    end;

    internal procedure OpenIdentificationTemplate(CDCDocument: Record "CDC Document"; IsXMLTemplate: Boolean)
    var
        CDCTemplate: Record "CDC Template";
        CDCTemplateCard: page "CDC Template Card";
    begin
        if IsXMLTemplate then begin
            CDCDocument.TestField("XML Ident. Template No.");
            if not CDCTemplate.Get(CDCDocument."XML Ident. Template No.") then
                exit;
        end else begin
            CDCTemplate.SetRange(Type, CDCTemplate.Type::Identification);
            CDCTemplate.SetRange("Data Type", CDCTemplate."Data Type"::PDF);
            if not CDCTemplate.FindFirst() then
                exit;
        end;
        CDCTemplateCard.SetRecord(CDCTemplate);
        CDCTemplateCard.Run();
    end;

    internal procedure CopyFieldSettingsToMasterTemplate(CDCDocument: Record "CDC Document")
    var
        CDCTemplate: Record "CDC Template";
        CDCTemplateField: Record "CDC Template Field";
        MasterCDCTemplateField: Record "CDC Template Field";
    begin
        CDCDocument.TestField("XML Master Template No.");
        if CDCTemplate.Get(CDCDocument."Template No.") then begin
            CDCTemplateField.SetRange("Template No.", CDCDocument."Template No.");
            CDCTemplateField.SetFilter("XML Path", '<>%1', '');
            if CDCTemplateField.FindSet() then
                repeat
                    if MasterCDCTemplateField.Get(CDCDocument."XML Master Template No.", CDCTemplateField.Type, CDCTemplateField.Code) then begin
                        MasterCDCTemplateField."XML Path" := CDCTemplateField."XML Path";
                        MasterCDCTemplateField.Modify();
                    end;
                until CDCTemplateField.Next() = 0;
        end;
    end;

    internal procedure OpenDocumentCategoryCard(DocumentCategory: Code[10])
    var
        CDCDocumentCategory: Record "CDC Document Category";
        CDCDocumentCategoryCard: Page "CDC Document Category Card";
    begin
        if CDCDocumentCategory.Get(DocumentCategory) then begin
            CDCDocumentCategoryCard.SetRecord(CDCDocumentCategory);
            CDCDocumentCategoryCard.Run();
        end
    end;

    internal procedure OpenMasterTemplateField(CDCTemplateField: Record "CDC Template Field")
    var
        CDCTemplate: Record "CDC Template";
        MasterCDCTemplateField: Record "CDC Template Field";
        CDCTemplateFieldCard: page "CDC Template Field Card";
    begin
        if not CDCTemplate.Get(CDCTemplateField."Template No.") then
            exit;

        CDCTemplate.TestField(Type, CDCTemplate.Type::" ");

        // Accept to raise an error, if master template doesn't exist anymore
        MasterCDCTemplateField.Get(CDCTemplate."Master Template No.", CDCTemplateField.Type, CDCTemplateField.Code);

        CDCTemplateFieldCard.SetRecord(MasterCDCTemplateField);
        CDCTemplateFieldCard.Caption := 'Master Template Field Card';
        CDCTemplateFieldCard.RunModal();
    end;

    internal procedure CopyTemplateField(SourceCDCTemplateField: Record "CDC Template Field")
    var
        CDCTemplate: Record "CDC Template";
        TargetCDCTemplateFieldTarget: Record "CDC Template Field";
        CDCTemplateList: Page "CDC Template List";
        CDCTemplateCard: Page "CDC Template Card";
    begin
        CDCTemplate.SetCurrentKey("Category Code", "Source Record ID Tree ID");
        CDCTemplateList.SetTableView(CDCTemplate);
        CDCTemplateList.LookupMode := true;
        if CDCTemplateList.RunModal() = Action::LookupOK then begin
            CDCTemplateList.GetRecord(CDCTemplate);
            TargetCDCTemplateFieldTarget.Init();
            TargetCDCTemplateFieldTarget.TransferFields(SourceCDCTemplateField, true);
            TargetCDCTemplateFieldTarget."Template No." := CDCTemplate."No.";
            TargetCDCTemplateFieldTarget.Insert(true);
            if Confirm('The field has been successfully copied. Click yes to open the template card of %1 (%2)', false, CDCTemplate.Description, CDCTemplate."No.") then begin
                CDCTemplateCard.SetRecord(CDCTemplate);
                CDCTemplateCard.Run();
            end;
        end;


    end;
}
