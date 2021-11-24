codeunit 61000 "Adv. Line Recognition Mgt."
{

    trigger OnRun()
    begin
    end;

    var
        FieldSetupCanceled: Label 'Field setup aborted because no field was selected!';
        FieldIsLinkedToSourceField: Label 'The field "%1" is now linked to field "%2"!';
        MissingSourceFieldValue: Label 'The value for source field %1 in line %2 is missing! Please train this value first!';
        MissingFieldExampleValue: Label 'The value for for %1 (%2) in row %3 is missing! Please train this value first!';
        SelectOffsetSourceFieldFirst: Label 'Please select first the source field on the basis of which position the value should be found. ';
        CodeunitDoesNotExist: Label 'Codeunit %1 does not exist! Has the object been renamed?';
        TrainCaptionFirstForField: Label 'Error! For the field %1 hasn|t been trained a caption! Please train the caption first.';
        SelectTheOffsetField: Label 'Please choose the field, which should be linked with the source field "%1".';
        ErrorDuringFieldSetup: Label 'Error during field setup.';
        SelectFieldForColumnHeaderSearch: Label 'Select the field that should be found by the column heading.';
        SelectFieldForCaptionSearch: Label 'Choose the field whose value should be found by the caption in the current line.';
        FieldIsCapturedByColumnHeading: Label 'The field "%1" will now be searched via the column heading "%2".';
        FieldIsCapturedByCaption: Label 'The value of field "%1" will now been searched via the caption in the current line.';
        NoRequiredFieldFound: Label 'No mandatory field with the option "Required" was found in line %1! Configure a mandatory field first.';
        ALRVersionNoText: Label 'ALR%1 (%2 Build %3)';
        NoALRFieldsForReset: Label 'There are not fields configured for advanced line recognition, that can be reset.';

    procedure SetToAnchorLinkedField(var TempDocumentLine: Record "CDC Temp. Document Line")
    var
        AnchorField: Record "CDC Template Field";
        LinkedField: Record "CDC Template Field";
        AnchorFieldDocumentValue: Record "CDC Document Value";
        LinkedFieldDocumentValue: Record "CDC Document Value";
        FieldsLinked: Integer;
    begin
        // Get the anchor field that defines the position
        Message(SelectOffsetSourceFieldFirst);
        SelectField(AnchorField, TempDocumentLine."Template No.", '', false);

        // Get document value of the anchor field => is mandatory
        AnchorFieldDocumentValue.SetRange("Document No.", TempDocumentLine."Document No.");
        AnchorFieldDocumentValue.SetRange("Is Value", true);
        AnchorFieldDocumentValue.SetRange(Code, AnchorField.Code);
        //AnchorFieldDocumentValue.SETRANGE("Line No.",1);
        AnchorFieldDocumentValue.SetRange("Line No.", TempDocumentLine."Line No.");
        AnchorFieldDocumentValue.SetRange(Type, AnchorFieldDocumentValue.Type::Line);
        AnchorFieldDocumentValue.SetRange("Is Valid", true);
        AnchorFieldDocumentValue.SetRange("Template No.", TempDocumentLine."Template No.");
        if not AnchorFieldDocumentValue.FindFirst then
            Error(MissingSourceFieldValue, AnchorField.Code, TempDocumentLine."Line No.");

        // Select the field that should be linked with anchor field
        Message(SelectTheOffsetField, AnchorField."Field Name");
        if not SelectField(LinkedField, TempDocumentLine."Template No.", AnchorField.Code, false) then
            Error(FieldSetupCanceled);

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
        if not LinkedFieldDocumentValue.FindFirst then
            Error(MissingFieldExampleValue, LinkedField."Field Name", LinkedField.Code);  //value is mandatory

        ResetField(LinkedField);

        // Calculate and save the offset values at the linked field
        LinkedField."Offset Top" := LinkedFieldDocumentValue.Top - AnchorFieldDocumentValue.Top;
        LinkedField."Offset Left" := LinkedFieldDocumentValue.Left - AnchorFieldDocumentValue.Left;
        LinkedField."Offset Bottom" := LinkedFieldDocumentValue.Bottom - LinkedFieldDocumentValue.Top;
        LinkedField."Offset Right" := LinkedFieldDocumentValue.Right - LinkedFieldDocumentValue.Left;
        LinkedField."Advanced Line Recognition Type" := LinkedField."Advanced Line Recognition Type"::LinkedToAnchorField;
        LinkedField."Anchor Field" := AnchorFieldDocumentValue.Code;

        UpdateExecutionSequence(LinkedField, LinkedField."Anchor Field");

        if LinkedField.Modify(true) then begin
            SetTemplateToALRProcessing(TempDocumentLine."Template No.");
            Message(FieldIsLinkedToSourceField, LinkedField."Field Name", AnchorField."Field Name");
        end else
            Message(ErrorDuringFieldSetup);
    end;

    procedure SetToFieldSearchWithColumnHeding(var TempDocumentLine: Record "CDC Temp. Document Line")
    var
        LineIdentFieldDocumentValue: Record "CDC Document Value";
        SelectedField: Record "CDC Template Field";
        SelectedFieldDocumentValue: Record "CDC Document Value";
        TemplateFieldCaption: Record "CDC Template Field Caption";
    begin
        // Find field value of a normal position field
        GetLineIdentifierValue(TempDocumentLine, LineIdentFieldDocumentValue);

        // Select field
        Message(SelectFieldForColumnHeaderSearch);
        if not SelectField(SelectedField, TempDocumentLine."Template No.", '', false) then
            Error(FieldSetupCanceled);

        // Check that the selected field has at least one caption
        TemplateFieldCaption.SetRange("Template No.", SelectedField."Template No.");
        TemplateFieldCaption.SetRange(Code, SelectedField.Code);
        TemplateFieldCaption.SetRange(Type, TemplateFieldCaption.Type::Line);
        if not TemplateFieldCaption.FindFirst then
            Error(TrainCaptionFirstForField, SelectedField.Code);

        // Find the value of the selected field
        GetSelectedFieldValue(TempDocumentLine, SelectedFieldDocumentValue, SelectedField);

        ResetField(SelectedField);

        // Setup field for column heading search
        SelectedField."Advanced Line Recognition Type" := SelectedField."Advanced Line Recognition Type"::FindFieldByColumnHeading;

        if SelectedFieldDocumentValue.Top < LineIdentFieldDocumentValue.Top then
            SelectedField."Field Position" := SelectedField."Field Position"::StandardLine
        else
            SelectedField."Field Position" := SelectedField."Field Position"::BelowStandardLine;

        if SelectedField.Modify(true) then begin
            SetTemplateToALRProcessing(TempDocumentLine."Template No.");
            Message(FieldIsCapturedByColumnHeading, SelectedField."Field Name", TemplateFieldCaption.Caption);
        end else
            Message(ErrorDuringFieldSetup);
    end;

    procedure SetToFieldSearchWithCaption(var TempDocumentLine: Record "CDC Temp. Document Line")
    var
        LineIdentFieldDocumentValue: Record "CDC Document Value";
        SelectedField: Record "CDC Template Field";
        SelectedFieldDocumentValue: Record "CDC Document Value";
        TemplateFieldCaption: Record "CDC Template Field Caption";
        DocumentPage: Record "CDC Document Page";
        CaptureEngine: Codeunit "CDC Capture Engine";
    begin
        // Find field value of a normal position field
        GetLineIdentifierValue(TempDocumentLine, LineIdentFieldDocumentValue);

        // Select field
        Message(SelectFieldForCaptionSearch);
        if not SelectField(SelectedField, TempDocumentLine."Template No.", '', false) then
            Error(FieldSetupCanceled);

        // Check that the selected field has at least one caption
        TemplateFieldCaption.SetRange("Template No.", SelectedField."Template No.");
        TemplateFieldCaption.SetRange(Code, SelectedField.Code);
        TemplateFieldCaption.SetRange(Type, TemplateFieldCaption.Type::Line);
        if not TemplateFieldCaption.FindFirst then
            Error(TrainCaptionFirstForField, SelectedField.Code);

        // Find the value of the selected field
        GetSelectedFieldValue(TempDocumentLine, SelectedFieldDocumentValue, SelectedField);

        ResetField(SelectedField);

        if (SelectedFieldDocumentValue.Right - SelectedFieldDocumentValue.Left) > 0 then begin
            DocumentPage.Get(TempDocumentLine."Document No.", TempDocumentLine."Page No.");
            SelectedField."ALR Typical Value Field Width" := Round((SelectedFieldDocumentValue.Right - SelectedFieldDocumentValue.Left)
                                                                   / CaptureEngine.GetDPIFactor(150, DocumentPage."TIFF Image Resolution"), 1);
        end;

        if (SelectedFieldDocumentValue.Top <> 0) and (TemplateFieldCaption.Top <> 0) and (SelectedFieldDocumentValue.Left <> 0) and (TemplateFieldCaption.Left <> 0) then begin
            SelectedField."ALR Value Caption Offset X" := SelectedFieldDocumentValue.Left - TemplateFieldCaption.Left;
            SelectedField."ALR Value Caption Offset Y" := SelectedFieldDocumentValue.Top - TemplateFieldCaption.Top;
        end;

        SelectedField."Caption Mandatory" := true;

        // Setup field for field search by caption
        SelectedField."Advanced Line Recognition Type" := SelectedField."Advanced Line Recognition Type"::FindFieldByCaptionInPosition;

        if SelectedFieldDocumentValue.Top < LineIdentFieldDocumentValue.Top then
            SelectedField."Field Position" := SelectedField."Field Position"::StandardLine
        else
            SelectedField."Field Position" := SelectedField."Field Position"::BelowStandardLine;

        if SelectedField.Modify(true) then begin
            ;
            SetTemplateToALRProcessing(TempDocumentLine."Template No.");
            Message(FieldIsCapturedByCaption, SelectedField."Field Name");
        end else
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
        Clear(TemplateField."Anchor Field");
        Clear(TemplateField."Offset Top");
        Clear(TemplateField."Offset Bottom");
        Clear(TemplateField."Offset Left");
        Clear(TemplateField."Offset Right");
        Clear(TemplateField."Field Position");
        Clear(TemplateField.Sorting);
        Clear(TemplateField."Substitution Field");
        Clear(TemplateField."Get Value from Previous Value");
        Clear(TemplateField."ALR Typical Value Field Width");
        Clear(TemplateField."Typical Field Height");
        Clear(TemplateField."Caption Mandatory");
        Clear(TemplateField."ALR Value Caption Offset X");
        Clear(TemplateField."ALR Value Caption Offset Y");
    end;

    local procedure SelectField(var TemplateField: Record "CDC Template Field"; TemplateNo: Code[20]; ExcludedFieldsFilter: Text[250]; ALROnlyFields: Boolean): Boolean
    var
        lTemplateFieldList: Page "CDC Template Field List";
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

        lTemplateFieldList.SetTableView(TemplateField);
        lTemplateFieldList.LookupMode(true);
        if lTemplateFieldList.RunModal = ACTION::LookupOK then begin
            lTemplateFieldList.GetRecord(TemplateField);
            exit(true);
        end;
    end;

    procedure SetTemplateToALRProcessing(TemplateNo: Code[20])
    var
        lTemplate: Record "CDC Template";
    begin
        // Change Codeunit ID to the advanced line recognition codeunit on template
        if lTemplate.Get(TemplateNo) then begin
            lTemplate.Validate("Codeunit ID: Line Capture", GetAdvLineRecCodeunit());
            lTemplate.Modify(true);
        end;
    end;


    local procedure GetAdvLineRecCodeunit(): Integer
    var
    begin
        exit(61001);
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
        if LineIdentField.FindSet then
            repeat
                //IF LineIdentFieldDocumentValue.GET(TempDocumentLine."Document No.",TRUE,LineIdentField.Code,1) THEN
                if LineIdentFieldDocumentValue.Get(TempDocumentLine."Document No.", true, LineIdentField.Code, TempDocumentLine."Line No.") then
                    if (LineIdentFieldDocumentValue."Template No." = TempDocumentLine."Template No.") and
                       (LineIdentFieldDocumentValue.Type = LineIdentFieldDocumentValue.Type::Line)
                    then
                        LineIdentFieldFound := true;
            until (LineIdentField.Next = 0) or LineIdentFieldFound;

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
        if not SelectedFieldDocumentValue.FindFirst then
            Error(MissingFieldExampleValue, SelectedField."Field Name", SelectedField.Code);  //value is mandatory
    end;

    local procedure UpdateExecutionSequence(var LinkedField: Record "CDC Template Field"; PreviousFieldCode: Code[20])
    var
        CurrField: Record "CDC Template Field";
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
            if SortField.FindSet then
                repeat
                    SortField.Sorting := SortField.Sorting + 1;
                    SortField.Modify;
                until SortField.Next = 0;
            LinkedField.Sorting := LinkedField.Sorting + 1;
        end;
    end;

    procedure ShowVersionNo(): Text
    var
        VersionTriggers: Codeunit "Version Triggers";
        ApplicationVersion: Text;
        ApplicationBuild: Text;
    begin
        //EXIT(12) //=> for older NAV/BC Versions without the version triggers
        VersionTriggers.GetApplicationVersion(ApplicationVersion);
        VersionTriggers.GetApplicationBuild(ApplicationBuild);

        exit(StrSubstNo(ALRVersionNoText, '13', ApplicationVersion, ApplicationBuild));
    end;
}

