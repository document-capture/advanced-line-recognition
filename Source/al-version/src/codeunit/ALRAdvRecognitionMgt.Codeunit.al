codeunit 61000 "ALR Adv. Recognition Mgt."
{
    var
        CDCCaptureEngine: Codeunit "CDC Capture Engine";
        FieldSetupCanceledLbl: Label 'Field setup aborted because no field was selected!';
        FieldIsLinkedToSourceFieldLbl: Label 'The field "%1" is now linked to field "%2"!', Comment = '%1 = field description of selected field | %2 = field description of linked field';
        MissingSourceFieldValueLbl: Label 'The value for source field "%1" in line %2 is missing! Please train this value first!', Comment = '%1 = source field description | %2 = line no';
        lblMissingFieldExampleValueLbl: Label 'The value for for %1 (%2) in line %3 is missing! Please train this value first!', Comment = 'Label gives an error when no field value has been captured for a selected field. %1 = Field description, %2 = Field code, %3 = current line no.';
        SelectOffsetSourceFieldFirstLbl: Label 'Please select first the source field on the basis of which position the value should be found. ';
        TrainCaptionFirstForFieldLbl: Label 'No caption has been configured for field "%1". You must configure the caption first.', Comment = ' %1 = field description';
        SelectTheOffsetFieldLbl: Label 'Please choose the field, which should be linked with the source field "%1".', Comment = ' %1 = field description of source field';
        ErrorDuringFieldSetupLbl: Label 'Error during field setup.';
        SelectFieldForColumnHeaderSearchLbl: Label 'Select the field that should be found by the column heading.';
        SelectFieldForCaptionSearchLbl: Label 'Choose the field whose value should be found by the caption in the current line.';
        FieldIsCapturedByColumnHeadingLbl: Label 'The field "%1" will now be searched via the column heading "%2".', Comment = '%1 = field description | %2 = caption of column heading';
        FieldIsCapturedByCaptionLbl: Label 'The value of field "%1" will now been searched via the caption in the current line.', Comment = '%1 = field description';
        NoRequiredFieldFoundLbl: Label 'No mandatory field with the option "Required" was found in line %1! Configure a mandatory field first.', Comment = '%1 = line no.';
        ALRVersionNoTextLbl: Label '%1 (Data %2) | Business Central version:%3 (Build %4)', Comment = '%1 = ALR app version |%2 = ALR data version | %3 = BC version | %4 = BC build';
        NoALRFieldsForResetLbl: Label 'There are not fields configured for advanced line recognition, that can be reset.';
        YouAreUsingALRVersionLbl: Label 'You are using version advanced line recognition version: %1', Comment = '%1 Displays the current version of the Advanced line recognition to the user including the build';


    procedure SetToAnchorLinkedField(var CDCTempDocumentLine: Record "CDC Temp. Document Line")
    var
        AnchorCDCTemplateField: Record "CDC Template Field";
        LinkedCDCTemplateField: Record "CDC Template Field";
        AnchorCDCDocumentValue: Record "CDC Document Value";
        LinkedCDCDocumentValue: Record "CDC Document Value";
    begin
        // Get the anchor field that defines the position

        Message(SelectOffsetSourceFieldFirstLbl);
        if (not SelectField(AnchorCDCTemplateField, CDCTempDocumentLine."Template No.", '', false)) then
            error(FieldSetupCanceledLbl);

        // Get document value of the anchor field => is mandatory
        AnchorCDCDocumentValue.SetRange("Document No.", CDCTempDocumentLine."Document No.");
        AnchorCDCDocumentValue.SetRange("Is Value", true);
        AnchorCDCDocumentValue.SetRange(Code, AnchorCDCTemplateField.Code);
        //AnchorCDCDocumentValue.SETRANGE("Line No.",1);
        AnchorCDCDocumentValue.SetRange("Line No.", CDCTempDocumentLine."Line No.");
        AnchorCDCDocumentValue.SetRange(Type, AnchorCDCDocumentValue.Type::Line);
        AnchorCDCDocumentValue.SetRange("Is Valid", true);
        AnchorCDCDocumentValue.SetRange("Template No.", CDCTempDocumentLine."Template No.");
        if not AnchorCDCDocumentValue.FindFirst() then
            Error(MissingSourceFieldValueLbl, AnchorCDCTemplateField.Code, CDCTempDocumentLine."Line No.");

        if LinkedCDCTemplateField.Code = '' then begin
            Message(SelectTheOffsetFieldLbl, AnchorCDCTemplateField."Field Name");
            if not SelectField(LinkedCDCTemplateField, CDCTempDocumentLine."Template No.", AnchorCDCTemplateField.Code, false) then
                Error(FieldSetupCanceledLbl);
        end;

        // Link the selected field to anchor field
        // Find the value of the selected field
        LinkedCDCDocumentValue.SetRange("Document No.", CDCTempDocumentLine."Document No.");
        LinkedCDCDocumentValue.SetRange("Is Value", true);
        LinkedCDCDocumentValue.SetRange(Code, LinkedCDCTemplateField.Code);
        //LinkedCDCDocumentValue.SETRANGE("Line No.",1);
        LinkedCDCDocumentValue.SetRange("Line No.", CDCTempDocumentLine."Line No.");
        LinkedCDCDocumentValue.SetRange(Type, LinkedCDCDocumentValue.Type::Line);
        LinkedCDCDocumentValue.SetRange("Is Valid", true);
        LinkedCDCDocumentValue.SetRange("Template No.", CDCTempDocumentLine."Template No.");
        if not LinkedCDCDocumentValue.FindFirst() then
            Error(lblMissingFieldExampleValueLbl, LinkedCDCTemplateField."Field Name", LinkedCDCTemplateField.Code, CDCTempDocumentLine."Line No.");  //value is mandatory

        ResetField(LinkedCDCTemplateField);

        // Calculate and save the offset values at the linked field
        LinkedCDCTemplateField."Offset Top" := LinkedCDCDocumentValue.Top - AnchorCDCDocumentValue.Top;
        LinkedCDCTemplateField."Offset Left" := LinkedCDCDocumentValue.Left - AnchorCDCDocumentValue.Left;
        LinkedCDCTemplateField."Offset Bottom" := LinkedCDCDocumentValue.Bottom - LinkedCDCDocumentValue.Top;
        LinkedCDCTemplateField."Offset Right" := LinkedCDCDocumentValue.Right - LinkedCDCDocumentValue.Left;
        LinkedCDCTemplateField."Advanced Line Recognition Type" := LinkedCDCTemplateField."Advanced Line Recognition Type"::LinkedToAnchorField;
        LinkedCDCTemplateField."Linked Field" := AnchorCDCDocumentValue.Code;

        UpdateExecutionSequence(LinkedCDCTemplateField, LinkedCDCTemplateField."Linked Field");

        if LinkedCDCTemplateField.Modify(true) then
            Message(FieldIsLinkedToSourceFieldLbl, LinkedCDCTemplateField."Field Name", AnchorCDCTemplateField."Field Name")
        else
            Message(ErrorDuringFieldSetupLbl);
    end;

    procedure SetToFieldSearchWithColumnHeding(var CDCTempDocumentLine: Record "CDC Temp. Document Line")
    var
        LineIdentFieldCDCDocumentValue: Record "CDC Document Value";
        SelectedCDCTemplateField: Record "CDC Template Field";
        SelectedCDCDocumentValue: Record "CDC Document Value";
        CDCTemplateFieldCaption: Record "CDC Template Field Caption";
    begin
        // Find field value of a normal position field
        GetLineIdentifierValue(CDCTempDocumentLine, LineIdentFieldCDCDocumentValue);

        // Select field
        if SelectedCDCTemplateField.Code = '' then begin
            Message(SelectFieldForColumnHeaderSearchLbl);
            if not SelectField(SelectedCDCTemplateField, CDCTempDocumentLine."Template No.", '', false) then
                Error(FieldSetupCanceledLbl);
        end;

        // Check that the selected field has at least one caption
        CDCTemplateFieldCaption.SetRange("Template No.", SelectedCDCTemplateField."Template No.");
        CDCTemplateFieldCaption.SetRange(Code, SelectedCDCTemplateField.Code);
        CDCTemplateFieldCaption.SetRange(Type, CDCTemplateFieldCaption.Type::Line);
        if not CDCTemplateFieldCaption.FindFirst() then
            Error(TrainCaptionFirstForFieldLbl, SelectedCDCTemplateField.Code);

        // Find the value of the selected field
        GetSelectedCDCTemplateFieldValue(CDCTempDocumentLine, SelectedCDCDocumentValue, SelectedCDCTemplateField);

        ResetField(SelectedCDCTemplateField);

        // Setup field for column heading search
        SelectedCDCTemplateField."Advanced Line Recognition Type" := SelectedCDCTemplateField."Advanced Line Recognition Type"::FindFieldByColumnHeading;

        if SelectedCDCDocumentValue.Top < LineIdentFieldCDCDocumentValue.Top then
            SelectedCDCTemplateField."Field value position" := SelectedCDCTemplateField."Field value position"::AboveStandardLine
        else
            SelectedCDCTemplateField."Field value position" := SelectedCDCTemplateField."Field value position"::BelowStandardLine;

        if SelectedCDCTemplateField.Modify(true) then
            Message(FieldIsCapturedByColumnHeadingLbl, SelectedCDCTemplateField."Field Name", CDCTemplateFieldCaption.Caption)
        else
            Message(ErrorDuringFieldSetupLbl);
    end;

    procedure SetToFieldSearchWithCaption(var CDCTempDocumentLine: Record "CDC Temp. Document Line")
    var
        LineIdentFieldCDCDocumentValue: Record "CDC Document Value";
        SelectedCDCTemplateField: Record "CDC Template Field";
        SelectedCDCDocumentValue: Record "CDC Document Value";
        CDCTemplateFieldCaption: Record "CDC Template Field Caption";
        CDCDocumentPage: Record "CDC Document Page";
    begin
        // Find field value of a normal position field
        GetLineIdentifierValue(CDCTempDocumentLine, LineIdentFieldCDCDocumentValue);

        // Select field
        if SelectedCDCTemplateField.Code = '' then begin
            Message(SelectFieldForCaptionSearchLbl);
            if not SelectField(SelectedCDCTemplateField, CDCTempDocumentLine."Template No.", '', false) then
                Error(FieldSetupCanceledLbl);
        end;

        // Check that the selected field has at least one caption
        CDCTemplateFieldCaption.SetRange("Template No.", SelectedCDCTemplateField."Template No.");
        CDCTemplateFieldCaption.SetRange(Code, SelectedCDCTemplateField.Code);
        CDCTemplateFieldCaption.SetRange(Type, CDCTemplateFieldCaption.Type::Line);
        if not CDCTemplateFieldCaption.FindFirst() then
            Error(TrainCaptionFirstForFieldLbl, SelectedCDCTemplateField.Code);

        // Find the value of the selected field
        GetSelectedCDCTemplateFieldValue(CDCTempDocumentLine, SelectedCDCDocumentValue, SelectedCDCTemplateField);

        ResetField(SelectedCDCTemplateField);

        if (SelectedCDCDocumentValue.Right - SelectedCDCDocumentValue.Left) > 0 then begin
            CDCDocumentPage.Get(CDCTempDocumentLine."Document No.", CDCTempDocumentLine."Page No.");
            SelectedCDCTemplateField."ALR Typical Value Field Width" := Round((SelectedCDCDocumentValue.Right - SelectedCDCDocumentValue.Left)
                                                                   / CDCCaptureEngine.GetDPIFactor(150, CDCDocumentPage."TIFF Image Resolution"), 1);
        end;

        if (SelectedCDCDocumentValue.Top <> 0) and (CDCTemplateFieldCaption.Top <> 0) and (SelectedCDCDocumentValue.Left <> 0) and (CDCTemplateFieldCaption.Left <> 0) then begin
            SelectedCDCTemplateField."ALR Value Caption Offset X" := SelectedCDCDocumentValue.Left - CDCTemplateFieldCaption.Left;
            SelectedCDCTemplateField."ALR Value Caption Offset Y" := SelectedCDCDocumentValue.Top - CDCTemplateFieldCaption.Top;
        end;

        SelectedCDCTemplateField."Caption Mandatory" := true;

        // Setup field for field search by caption
        SelectedCDCTemplateField."Advanced Line Recognition Type" := SelectedCDCTemplateField."Advanced Line Recognition Type"::FindFieldByCaptionInPosition;

        if SelectedCDCDocumentValue.Top < LineIdentFieldCDCDocumentValue.Top then
            SelectedCDCTemplateField."Field value position" := SelectedCDCTemplateField."Field value position"::AboveStandardLine
        else
            SelectedCDCTemplateField."Field value position" := SelectedCDCTemplateField."Field value position"::BelowStandardLine;

        if SelectedCDCTemplateField.Modify(true) then
            Message(FieldIsCapturedByCaptionLbl, SelectedCDCTemplateField."Field Name")
        else
            Message(ErrorDuringFieldSetupLbl);
    end;

    procedure ResetFieldFromMenu(var CDCTempDocumentLine: Record "CDC Temp. Document Line")
    var
        ToResetCDCTemplateField: Record "CDC Template Field";
    begin
        if SelectField(ToResetCDCTemplateField, CDCTempDocumentLine."Template No.", '', true) then begin
            ResetField(ToResetCDCTemplateField);
            ToResetCDCTemplateField.Modify(true);
        end;
    end;

    local procedure ResetField(var CDCTemplateField: Record "CDC Template Field")
    begin
        // Reset the current field to default values
        CDCTemplateField."Search for Value" := false;
        CDCTemplateField.Required := false;
        Clear(CDCTemplateField."Advanced Line Recognition Type");
        Clear(CDCTemplateField."Linked Field");
        Clear(CDCTemplateField."Offset Top");
        Clear(CDCTemplateField."Offset Bottom");
        Clear(CDCTemplateField."Offset Left");
        Clear(CDCTemplateField."Offset Right");
        Clear(CDCTemplateField."Field value position");
        Clear(CDCTemplateField."Field value search direction");
        Clear(CDCTemplateField.Sorting);
        Clear(CDCTemplateField."Replacement Field");
        //Clear(CDCTemplateField."Replacement Field Type");
        Clear(CDCTemplateField."Copy Value from Previous Value");
        Clear(CDCTemplateField."ALR Typical Value Field Width");
        Clear(CDCTemplateField."Typical Field Height");
        Clear(CDCTemplateField."Caption Mandatory");
        Clear(CDCTemplateField."ALR Value Caption Offset X");
        Clear(CDCTemplateField."ALR Value Caption Offset Y");
    end;

    local procedure SelectField(var CDCTemplateField: Record "CDC Template Field"; TemplateNo: Code[20]; ExcludedFieldsFilter: Text[250]; ALROnlyFields: Boolean): Boolean
    var
        CDCTemplateFieldList: Page "CDC Template Field List";
    begin
        CDCTemplateField.SetRange("Template No.", TemplateNo);
        CDCTemplateField.SetRange(Type, CDCTemplateField.Type::Line);

        if ExcludedFieldsFilter <> '' then
            CDCTemplateField.SetFilter(Code, '<>%1', ExcludedFieldsFilter);

        if ALROnlyFields then begin
            CDCTemplateField.SetFilter("Advanced Line Recognition Type", '<>%1', CDCTemplateField."Advanced Line Recognition Type"::Default);
            if CDCTemplateField.IsEmpty then
                Error(NoALRFieldsForResetLbl);
        end;

        CDCTemplateFieldList.SetTableView(CDCTemplateField);
        CDCTemplateFieldList.LookupMode(true);
        if CDCTemplateFieldList.RunModal() = ACTION::LookupOK then begin
            CDCTemplateFieldList.GetRecord(CDCTemplateField);
            exit(true);
        end;
    end;

    local procedure GetLineIdentifierValue(var CDCTempDocumentLine: Record "CDC Temp. Document Line"; var LineIdentFieldCDCDocumentValue: Record "CDC Document Value")
    var
        LineIdentCDCTemplateField: Record "CDC Template Field";
        LineIdentFieldFound: Boolean;
    begin

        LineIdentCDCTemplateField.SetRange("Template No.", CDCTempDocumentLine."Template No.");
        LineIdentCDCTemplateField.SetRange(Type, LineIdentCDCTemplateField.Type::Line);
        LineIdentCDCTemplateField.SetRange(Required, true);
        LineIdentCDCTemplateField.SetRange("Advanced Line Recognition Type", LineIdentCDCTemplateField."Advanced Line Recognition Type"::Default);
        if LineIdentCDCTemplateField.FindSet() then
            repeat
                //IF LineIdentFieldCDCDocumentValue.GET(CDCTempDocumentLine."Document No.",TRUE,LineIdentCDCTemplateField.Code,1) THEN
                if LineIdentFieldCDCDocumentValue.Get(CDCTempDocumentLine."Document No.", true, LineIdentCDCTemplateField.Code, CDCTempDocumentLine."Line No.") then
                    if (LineIdentFieldCDCDocumentValue."Template No." = CDCTempDocumentLine."Template No.") and
                       (LineIdentFieldCDCDocumentValue.Type = LineIdentFieldCDCDocumentValue.Type::Line)
                    then
                        LineIdentFieldFound := true;
            until (LineIdentCDCTemplateField.Next() = 0) or LineIdentFieldFound;

        if not LineIdentFieldFound then
            Error(NoRequiredFieldFoundLbl);
    end;

    local procedure GetSelectedCDCTemplateFieldValue(var CDCTempDocumentLine: Record "CDC Temp. Document Line"; var SelectedCDCDocumentValue: Record "CDC Document Value"; SelectedCDCTemplateField: Record "CDC Template Field")
    begin
        SelectedCDCDocumentValue.SetRange("Document No.", CDCTempDocumentLine."Document No.");
        SelectedCDCDocumentValue.SetRange("Is Value", true);
        SelectedCDCDocumentValue.SetRange(Code, SelectedCDCTemplateField.Code);
        //SelectedCDCDocumentValue.SETRANGE("Line No.",0,1);
        SelectedCDCDocumentValue.SetRange("Line No.", CDCTempDocumentLine."Line No.");
        SelectedCDCDocumentValue.SetRange(Type, SelectedCDCDocumentValue.Type::Line);
        SelectedCDCDocumentValue.SetRange("Is Valid", true);
        SelectedCDCDocumentValue.SetRange("Template No.", CDCTempDocumentLine."Template No.");
        if not SelectedCDCDocumentValue.FindFirst() then
            Error(lblMissingFieldExampleValueLbl, SelectedCDCTemplateField."Field Name", SelectedCDCTemplateField.Code, CDCTempDocumentLine."Line No.");  //value is mandatory
    end;

    local procedure UpdateExecutionSequence(var LinkedCDCTemplateField: Record "CDC Template Field"; PreviousFieldCode: Code[20])
    var
        PrevCDCTemplateField: Record "CDC Template Field";
        SortCDCTemplateField: Record "CDC Template Field";
    begin
        if not PrevCDCTemplateField.Get(LinkedCDCTemplateField."Template No.", PrevCDCTemplateField.Type::Line, PreviousFieldCode) then
            exit;

        if LinkedCDCTemplateField.Sorting <= PrevCDCTemplateField.Sorting then begin
            SortCDCTemplateField.SetRange("Template No.", LinkedCDCTemplateField."Template No.");
            SortCDCTemplateField.SetRange(Type, SortCDCTemplateField.Type::Line);
            SortCDCTemplateField.SetFilter(Code, '<>%1', LinkedCDCTemplateField.Code);
            SortCDCTemplateField.SetFilter(Sorting, '>=%1', LinkedCDCTemplateField.Sorting + 1);
            if SortCDCTemplateField.FindSet() then
                repeat
                    SortCDCTemplateField.Sorting := SortCDCTemplateField.Sorting + 1;
                    SortCDCTemplateField.Modify();
                until SortCDCTemplateField.Next() = 0;
            LinkedCDCTemplateField.Sorting := LinkedCDCTemplateField.Sorting + 1;
        end;
    end;

    procedure ShowVersionNo(): Text
    var
        VersionTriggers: Codeunit "Version Triggers";
        ALRUpgradeManagement: Codeunit "ALR Upgrade Management";
        ModInfo: ModuleInfo;
        ApplicationVersion: Text[248];
        ApplicationBuild: Text[80];
    begin
        VersionTriggers.GetApplicationVersion(ApplicationVersion);
        VersionTriggers.GetApplicationBuild(ApplicationBuild);
        NavApp.GetCurrentModuleInfo(ModInfo);

        Message(YouAreUsingALRVersionLbl, StrSubstNo(ALRVersionNoTextLbl, ModInfo.AppVersion, ALRUpgradeManagement.GetDataVersion(), ApplicationVersion, ApplicationBuild));
    end;
}