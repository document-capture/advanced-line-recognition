codeunit 61000 "ALR Adv. Recognition Mgt."
{
#pragma warning disable AA0072
#pragma warning disable AA0074
    trigger OnRun()
    begin
    end;

    var
        ALRMgtSI: Codeunit "ALR Single Instance Mgt.";
        FieldSetupCanceled: Label 'Field setup aborted because no field was selected!';
        FieldIsLinkedToSourceField: Label 'The field "%1" is now linked to field "%2"!', Comment = '%1 = field description of selected field | %2 = field description of linked field';
        MissingSourceFieldValue: Label 'The value for source field "%1" in line %2 is missing! Please train this value first!', Comment = '%1 = source field description | %2 = line no';
        lblMissingFieldExampleValue: Label 'The value for for %1 (%2) in line %3 is missing! Please train this value first!', Comment = 'Label gives an error when no field value has been captured for a selected field. %1 = Field description, %2 = Field code, %3 = current line no.';
        SelectOffsetSourceFieldFirst: Label 'Please select first the source field on the basis of which position the value should be found. ';
        TrainCaptionFirstForField: Label 'No caption has been configured for field "%1". You must configure the caption first.', Comment = ' %1 = field description';
        SelectTheOffsetField: Label 'Please choose the field, which should be linked with the source field "%1".', Comment = ' %1 = field description of source field';
        ErrorDuringFieldSetup: Label 'Error during field setup.';
        SelectFieldForColumnHeaderSearch: Label 'Select the field that should be found by the column heading.';
        SelectFieldForCaptionSearch: Label 'Choose the field whose value should be found by the caption in the current line.';
        FieldIsCapturedByColumnHeading: Label 'The field "%1" will now be searched via the column heading "%2".', Comment = '%1 = field description | %2 = caption of column heading';
        FieldIsCapturedByCaption: Label 'The value of field "%1" will now been searched via the caption in the current line.', Comment = '%1 = field description';
        NoRequiredFieldFound: Label 'No mandatory field with the option "Required" was found in line %1! Configure a mandatory field first.', Comment = '%1 = line no.';
        ALRVersionNoText: Label '%1 | Business Central version:%2 (Build %3)', Comment = '%1 = ALR object version | %2 = BC version | %3 = BC build';
        NoALRFieldsForReset: Label 'There are not fields configured for advanced line recognition, that can be reset.';
        YouAreUsingALRVersion: Label 'You are using version advanced line recognition version: %1', Comment = '%1 Displays the current version of the Advanced line recognition to the user including the build';


    procedure SetToAnchorLinkedField(var TempDocumentLine: Record "CDC Temp. Document Line")
    var
        AnchorField: Record "CDC Template Field";
        LinkedField: Record "CDC Template Field";
        AnchorFieldDocumentValue: Record "CDC Document Value";
        LinkedFieldDocumentValue: Record "CDC Document Value";
    begin
        // Get the anchor field that defines the position

        Message(SelectOffsetSourceFieldFirst);
        if (not SelectField(AnchorField, TempDocumentLine."Template No.", '', false)) then
            error(FieldSetupCanceled);

        // Get document value of the anchor field => is mandatory
        AnchorFieldDocumentValue.SetRange("Document No.", TempDocumentLine."Document No.");
        AnchorFieldDocumentValue.SetRange("Is Value", true);
        AnchorFieldDocumentValue.SetRange(Code, AnchorField.Code);
        //AnchorFieldDocumentValue.SETRANGE("Line No.",1);
        AnchorFieldDocumentValue.SetRange("Line No.", TempDocumentLine."Line No.");
        AnchorFieldDocumentValue.SetRange(Type, AnchorFieldDocumentValue.Type::Line);
        AnchorFieldDocumentValue.SetRange("Is Valid", true);
        AnchorFieldDocumentValue.SetRange("Template No.", TempDocumentLine."Template No.");
        if not AnchorFieldDocumentValue.FindFirst() then
            Error(MissingSourceFieldValue, AnchorField.Code, TempDocumentLine."Line No.");

        // Select the field that should be linked with anchor field
        if (ALRMgtSI.GetAutoFieldRecognition() AND (ALRMgtSI.GetLastCapturedField() <> '')) then
            if not LinkedField.Get(TempDocumentLine."Template No.", LinkedField.Type::Line, ALRMgtSI.GetLastCapturedField()) then;

        if LinkedField.Code = '' then begin
            Message(SelectTheOffsetField, AnchorField."Field Name");
            if not SelectField(LinkedField, TempDocumentLine."Template No.", AnchorField.Code, false) then
                Error(FieldSetupCanceled);
        end;

        // Link the selected field to anchor field
        // Find the value of the selected field
        LinkedFieldDocumentValue.SetRange("Document No.", TempDocumentLine."Document No.");
        LinkedFieldDocumentValue.SetRange("Is Value", true);
        LinkedFieldDocumentValue.SetRange(Code, LinkedField.Code);
        //LinkedFieldDocumentValue.SETRANGE("Line No.",1);
        LinkedFieldDocumentValue.SetRange("Line No.", TempDocumentLine."Line No.");
        LinkedFieldDocumentValue.SetRange(Type, LinkedFieldDocumentValue.Type::Line);
        LinkedFieldDocumentValue.SetRange("Is Valid", true);
        LinkedFieldDocumentValue.SetRange("Template No.", TempDocumentLine."Template No.");
        if not LinkedFieldDocumentValue.FindFirst() then
            Error(lblMissingFieldExampleValue, LinkedField."Field Name", LinkedField.Code, TempDocumentLine."Line No.");  //value is mandatory

        ResetField(LinkedField);

        // Calculate and save the offset values at the linked field
        LinkedField."Offset Top" := LinkedFieldDocumentValue.Top - AnchorFieldDocumentValue.Top;
        LinkedField."Offset Left" := LinkedFieldDocumentValue.Left - AnchorFieldDocumentValue.Left;
        LinkedField."Offset Bottom" := LinkedFieldDocumentValue.Bottom - LinkedFieldDocumentValue.Top;
        LinkedField."Offset Right" := LinkedFieldDocumentValue.Right - LinkedFieldDocumentValue.Left;
        LinkedField."Advanced Line Recognition Type" := LinkedField."Advanced Line Recognition Type"::LinkedToAnchorField;
        LinkedField."Linked Field" := AnchorFieldDocumentValue.Code;

        UpdateExecutionSequence(LinkedField, LinkedField."Linked Field");

        if LinkedField.Modify(true) then
            Message(FieldIsLinkedToSourceField, LinkedField."Field Name", AnchorField."Field Name")
        else
            Message(ErrorDuringFieldSetup);
    end;

    procedure SetToFieldSearchWithColumnHeding(var TempDocumentLine: Record "CDC Temp. Document Line")
    var
        LineIdentFieldDocumentValue: Record "CDC Document Value";
        SelectedField: Record "CDC Template Field";
        SelectedFieldDocumentValue: Record "CDC Document Value";
        CDCTemplateFieldCaption: Record "CDC Template Field Caption";
    begin
        // Find field value of a normal position field
        GetLineIdentifierValue(TempDocumentLine, LineIdentFieldDocumentValue);

        // Select field
        if (ALRMgtSI.GetAutoFieldRecognition() AND (ALRMgtSI.GetLastCapturedField() <> '')) then
            if not SelectedField.Get(TempDocumentLine."Template No.", SelectedField.Type::Line, ALRMgtSI.GetLastCapturedField()) then;

        if SelectedField.Code = '' then begin
            Message(SelectFieldForColumnHeaderSearch);
            if not SelectField(SelectedField, TempDocumentLine."Template No.", '', false) then
                Error(FieldSetupCanceled);
        end;

        // Check that the selected field has at least one caption
        CDCTemplateFieldCaption.SetRange("Template No.", SelectedField."Template No.");
        CDCTemplateFieldCaption.SetRange(Code, SelectedField.Code);
        CDCTemplateFieldCaption.SetRange(Type, CDCTemplateFieldCaption.Type::Line);
        if not CDCTemplateFieldCaption.FindFirst() then
            Error(TrainCaptionFirstForField, SelectedField.Code);

        // Find the value of the selected field
        GetSelectedFieldValue(TempDocumentLine, SelectedFieldDocumentValue, SelectedField);

        ResetField(SelectedField);

        // Setup field for column heading search
        SelectedField."Advanced Line Recognition Type" := SelectedField."Advanced Line Recognition Type"::FindFieldByColumnHeading;

        if SelectedFieldDocumentValue.Top < LineIdentFieldDocumentValue.Top then
            SelectedField."Field value position" := SelectedField."Field value position"::AboveStandardLine
        else
            SelectedField."Field value position" := SelectedField."Field value position"::BelowStandardLine;

        if SelectedField.Modify(true) then
            Message(FieldIsCapturedByColumnHeading, SelectedField."Field Name", CDCTemplateFieldCaption.Caption)
        else
            Message(ErrorDuringFieldSetup);
    end;

    procedure SetToFieldSearchWithCaption(var TempDocumentLine: Record "CDC Temp. Document Line")
    var
        LineIdentFieldDocumentValue: Record "CDC Document Value";
        SelectedField: Record "CDC Template Field";
        SelectedFieldDocumentValue: Record "CDC Document Value";
#pragma warning disable AA0237
        CDCTemplateFieldCaption: Record "CDC Template Field Caption";
#pragma warning restore AA0237
        DocumentPage: Record "CDC Document Page";
        CaptureEngine: Codeunit "CDC Capture Engine";
    begin
        // Find field value of a normal position field
        GetLineIdentifierValue(TempDocumentLine, LineIdentFieldDocumentValue);

        // Select field
        if (ALRMgtSI.GetAutoFieldRecognition() AND (ALRMgtSI.GetLastCapturedField() <> '')) then
            if not SelectedField.Get(TempDocumentLine."Template No.", SelectedField.Type::Line, ALRMgtSI.GetLastCapturedField()) then;

        if SelectedField.Code = '' then begin
            Message(SelectFieldForCaptionSearch);
            if not SelectField(SelectedField, TempDocumentLine."Template No.", '', false) then
                Error(FieldSetupCanceled);
        end;

        // Check that the selected field has at least one caption
        CDCTemplateFieldCaption.SetRange("Template No.", SelectedField."Template No.");
        CDCTemplateFieldCaption.SetRange(Code, SelectedField.Code);
        CDCTemplateFieldCaption.SetRange(Type, CDCTemplateFieldCaption.Type::Line);
        if not CDCTemplateFieldCaption.FindFirst() then
            Error(TrainCaptionFirstForField, SelectedField.Code);

        // Find the value of the selected field
        GetSelectedFieldValue(TempDocumentLine, SelectedFieldDocumentValue, SelectedField);

        ResetField(SelectedField);

        if (SelectedFieldDocumentValue.Right - SelectedFieldDocumentValue.Left) > 0 then begin
            DocumentPage.Get(TempDocumentLine."Document No.", TempDocumentLine."Page No.");
            SelectedField."ALR Typical Value Field Width" := Round((SelectedFieldDocumentValue.Right - SelectedFieldDocumentValue.Left)
                                                                   / CaptureEngine.GetDPIFactor(150, DocumentPage."TIFF Image Resolution"), 1);
        end;

        if (SelectedFieldDocumentValue.Top <> 0) and (CDCTemplateFieldCaption.Top <> 0) and (SelectedFieldDocumentValue.Left <> 0) and (CDCTemplateFieldCaption.Left <> 0) then begin
            SelectedField."ALR Value Caption Offset X" := SelectedFieldDocumentValue.Left - CDCTemplateFieldCaption.Left;
            SelectedField."ALR Value Caption Offset Y" := SelectedFieldDocumentValue.Top - CDCTemplateFieldCaption.Top;
        end;

        SelectedField."Caption Mandatory" := true;

        // Setup field for field search by caption
        SelectedField."Advanced Line Recognition Type" := SelectedField."Advanced Line Recognition Type"::FindFieldByCaptionInPosition;

        if SelectedFieldDocumentValue.Top < LineIdentFieldDocumentValue.Top then
            SelectedField."Field value position" := SelectedField."Field value position"::AboveStandardLine
        else
            SelectedField."Field value position" := SelectedField."Field value position"::BelowStandardLine;

        if SelectedField.Modify(true) then
            Message(FieldIsCapturedByCaption, SelectedField."Field Name")
        else
            Message(ErrorDuringFieldSetup);
    end;

    procedure ResetFieldFromMenu(var TempDocumentLine: Record "CDC Temp. Document Line")
    var
        FieldToReset: Record "CDC Template Field";
    begin
        if SelectField(FieldToReset, TempDocumentLine."Template No.", '', true) then begin
            ResetField(FieldToReset);
            FieldToReset.Modify(true);
        end;
    end;

    local procedure ResetField(var TemplateField: Record "CDC Template Field")
    begin
        // Reset the current field to default values
        TemplateField."Search for Value" := false;
        TemplateField.Required := false;
        Clear(TemplateField."Advanced Line Recognition Type");
        Clear(TemplateField."Linked Field");
        Clear(TemplateField."Offset Top");
        Clear(TemplateField."Offset Bottom");
        Clear(TemplateField."Offset Left");
        Clear(TemplateField."Offset Right");
        Clear(TemplateField."Field value position");
        Clear(TemplateField."Field value search direction");
        Clear(TemplateField.Sorting);
        Clear(TemplateField."Replacement Field");
        Clear(TemplateField."Replacement Field Type");
        Clear(TemplateField."Copy Value from Previous Value");
        Clear(TemplateField."ALR Typical Value Field Width");
        Clear(TemplateField."Typical Field Height");
        Clear(TemplateField."Caption Mandatory");
        Clear(TemplateField."ALR Value Caption Offset X");
        Clear(TemplateField."ALR Value Caption Offset Y");
    end;

    local procedure SelectField(var TemplateField: Record "CDC Template Field"; TemplateNo: Code[20]; ExcludedFieldsFilter: Text[250]; ALROnlyFields: Boolean): Boolean
    var
        TemplateFieldList: Page "CDC Template Field List";
    begin
        TemplateField.SetRange("Template No.", TemplateNo);
        TemplateField.SetRange(Type, TemplateField.Type::Line);

        if ExcludedFieldsFilter <> '' then
            TemplateField.SetFilter(Code, '<>%1', ExcludedFieldsFilter);

        if ALROnlyFields then begin
            TemplateField.SetFilter("Advanced Line Recognition Type", '<>%1', TemplateField."Advanced Line Recognition Type"::Default);
            if TemplateField.IsEmpty then
                Error(NoALRFieldsForReset);
        end;

        TemplateFieldList.SetTableView(TemplateField);
        TemplateFieldList.LookupMode(true);
        if TemplateFieldList.RunModal() = ACTION::LookupOK then begin
            TemplateFieldList.GetRecord(TemplateField);
            exit(true);
        end;
    end;

    local procedure GetLineIdentifierValue(var TempDocumentLine: Record "CDC Temp. Document Line"; var LineIdentFieldDocumentValue: Record "CDC Document Value")
    var
        LineIdentField: Record "CDC Template Field";
        LineIdentFieldFound: Boolean;
    begin

        LineIdentField.SetRange("Template No.", TempDocumentLine."Template No.");
        LineIdentField.SetRange(Type, LineIdentField.Type::Line);
        LineIdentField.SetRange(Required, true);
        LineIdentField.SetRange("Advanced Line Recognition Type", LineIdentField."Advanced Line Recognition Type"::Default);
        if LineIdentField.FindSet() then
            repeat
                //IF LineIdentFieldDocumentValue.GET(TempDocumentLine."Document No.",TRUE,LineIdentField.Code,1) THEN
                if LineIdentFieldDocumentValue.Get(TempDocumentLine."Document No.", true, LineIdentField.Code, TempDocumentLine."Line No.") then
                    if (LineIdentFieldDocumentValue."Template No." = TempDocumentLine."Template No.") and
                       (LineIdentFieldDocumentValue.Type = LineIdentFieldDocumentValue.Type::Line)
                    then
                        LineIdentFieldFound := true;
            until (LineIdentField.Next() = 0) or LineIdentFieldFound;

        if not LineIdentFieldFound then
            Error(NoRequiredFieldFound);
    end;

    local procedure GetSelectedFieldValue(var TempDocumentLine: Record "CDC Temp. Document Line"; var SelectedFieldDocumentValue: Record "CDC Document Value"; SelectedField: Record "CDC Template Field")
    begin
        SelectedFieldDocumentValue.SetRange("Document No.", TempDocumentLine."Document No.");
        SelectedFieldDocumentValue.SetRange("Is Value", true);
        SelectedFieldDocumentValue.SetRange(Code, SelectedField.Code);
        //SelectedFieldDocumentValue.SETRANGE("Line No.",0,1);
        SelectedFieldDocumentValue.SetRange("Line No.", TempDocumentLine."Line No.");
        SelectedFieldDocumentValue.SetRange(Type, SelectedFieldDocumentValue.Type::Line);
        SelectedFieldDocumentValue.SetRange("Is Valid", true);
        SelectedFieldDocumentValue.SetRange("Template No.", TempDocumentLine."Template No.");
        if not SelectedFieldDocumentValue.FindFirst() then
            Error(lblMissingFieldExampleValue, SelectedField."Field Name", SelectedField.Code, TempDocumentLine."Line No.");  //value is mandatory
    end;

    local procedure UpdateExecutionSequence(var LinkedField: Record "CDC Template Field"; PreviousFieldCode: Code[20])
    var
        PrevField: Record "CDC Template Field";
        SortField: Record "CDC Template Field";
    begin
        if not PrevField.Get(LinkedField."Template No.", PrevField.Type::Line, PreviousFieldCode) then
            exit;

        if LinkedField.Sorting <= PrevField.Sorting then begin
            SortField.SetRange("Template No.", LinkedField."Template No.");
            SortField.SetRange(Type, SortField.Type::Line);
            SortField.SetFilter(Code, '<>%1', LinkedField.Code);
            SortField.SetFilter(Sorting, '>=%1', LinkedField.Sorting + 1);
            if SortField.FindSet() then
                repeat
                    SortField.Sorting := SortField.Sorting + 1;
                    SortField.Modify();
                until SortField.Next() = 0;
            LinkedField.Sorting := LinkedField.Sorting + 1;
        end;
    end;

    procedure ShowVersionNo(): Text
    var
        VersionTriggers: Codeunit "Version Triggers";
        InstallMgt: Codeunit "ALR Install Management";
        ApplicationVersion: Text[248];
        ApplicationBuild: Text[80];
    begin
        VersionTriggers.GetApplicationVersion(ApplicationVersion);
        VersionTriggers.GetApplicationBuild(ApplicationBuild);
        Message(YouAreUsingALRVersion, StrSubstNo(ALRVersionNoText, InstallMgt.GetDataVersion(), ApplicationVersion, ApplicationBuild));
    end;
}
#pragma warning restore