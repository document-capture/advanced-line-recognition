codeunit 61000 "ALR Adv. Line Recognition Mgt."
{
    // -----------------------------------------------------
    // CKL Software GmbH
    // 
    // Ver Date     Usr Change
    // -----------------------------------------------------
    // 001 20180301 SRA Initial Commit
    // 00 220180325 SRA New functions for Caption in Line and Offset Line
    //                  Renamed of existing functions
    // 004 20180717 SRA Redesign, new funtionality
    // 006 20190219 SRA New Function to reset a selectable field to standard capturing
    // 007 20190613 SRA New Object number due to conflicts with the default training objects
    // -----------------------------------------------------


    trigger OnRun()
    begin
    end;

    var
        Text001: Label 'Linking cancelled because you didn''t select fields for linking!';
        Text002: Label 'The field "%1" is now linked to the line identification field "%2"!';
        Text003: Label 'The line identification %1 field is not trained yet!';
        Text004: Label 'Please train the example value for %1 in the first document line!';
        Text005: Label 'Please choose the line identification field first!';
        Text006: Label 'Codeunit %1 does not exist!';
        Text007: Label 'The field "%1" will now be searched via the column heading "%2".';
        Text008: Label 'Error! For the field %1 hasn|t been trained a caption! Please train the caption first.';
        Text009: Label 'The value for field "%1" will be searched by the column heading now.';
        Text011: Label 'Please choose the line identification field first!';
        Text013: Label 'Choose the field, which should be linked with the line identifiying field.';
        Text014: Label 'Error during assigning the field';
        Text015: Label 'Select the field that should be found by the column heading.';
        Text016: Label 'Choose the field whose value should be found by the caption in the current line.';
        Text017: Label 'The value of field "%1" will now been searched via the caption in the current line.';
        Text020: Label 'There is no trained field for the first position yet! Please train one field in the position first.';

    procedure SetToAnchorLinkedField(var TempDocumentLine: Record "CDC Temp. Document Line")
    var
        AnchorField: Record "CDC Template Field";
        LinkedField: Record "CDC Template Field";
        AnchorFieldDocumentValue: Record "CDC Document Value";
        LinkedFieldDocumentValue: Record "CDC Document Value";
        FieldsLinked: Integer;
    begin
        // Get the anchor field that defines the position
        Message(Text005);
        SelectField(AnchorField, TempDocumentLine."Template No.", '');

        // Get document value of the anchor field => is mandatory
        AnchorFieldDocumentValue.SetRange("Document No.", TempDocumentLine."Document No.");
        AnchorFieldDocumentValue.SetRange("Is Value", true);
        AnchorFieldDocumentValue.SetRange(Code, AnchorField.Code);
        AnchorFieldDocumentValue.SetRange("Line No.", 1);
        AnchorFieldDocumentValue.SetRange(Type, AnchorFieldDocumentValue.Type::Line);
        AnchorFieldDocumentValue.SetRange("Is Valid", true);
        AnchorFieldDocumentValue.SetRange("Template No.", TempDocumentLine."Template No.");
        if not AnchorFieldDocumentValue.FindFirst then
            Error(Text003, AnchorField.Code);

        // Select the field that should be linked with anchor field
        Message(Text013);
        if not SelectField(LinkedField, TempDocumentLine."Template No.", AnchorField.Code) then
            Error(Text001);

        // Link the selected field to anchor field
        // Find the value of the selected field
        LinkedFieldDocumentValue.SetRange("Document No.", TempDocumentLine."Document No.");
        LinkedFieldDocumentValue.SetRange("Is Value", true);
        LinkedFieldDocumentValue.SetRange(Code, LinkedField.Code);
        LinkedFieldDocumentValue.SetRange("Line No.", 0, 1);
        LinkedFieldDocumentValue.SetRange(Type, LinkedFieldDocumentValue.Type::Line);
        LinkedFieldDocumentValue.SetRange("Is Valid", true);
        LinkedFieldDocumentValue.SetRange("Template No.", TempDocumentLine."Template No.");
        if not LinkedFieldDocumentValue.FindFirst then
            Error(Text004, LinkedField."Field Name", LinkedField.Code);  //value is mandatory

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
            Message(Text002, LinkedField."Field Name", AnchorField."Field Name");
        end else
            Message(Text014);
    end;

    procedure SetToFieldSearchWithColumnHeding(var TempDocumentLine: Record "CDC Temp. Document Line")
    var
        LineIdentFieldDocumentValue: Record "CDC Document Value";
        SelectedField: Record "CDC Template Field";
        SelectedFieldDocumentValue: Record "CDC Document Value";
        TemplateFieldCaption: Record "CDC Template Field Caption";
    begin
        // Find field value of a normal position field
        GetLineIdentifierValue(LineIdentFieldDocumentValue, TempDocumentLine."Document No.", TempDocumentLine."Template No.");

        // Select field
        Message(Text015);
        if not SelectField(SelectedField, TempDocumentLine."Template No.", '') then
            Error(Text001);

        // Check that the selected field has at least one caption
        TemplateFieldCaption.SetRange("Template No.", SelectedField."Template No.");
        TemplateFieldCaption.SetRange(Code, SelectedField.Code);
        TemplateFieldCaption.SetRange(Type, TemplateFieldCaption.Type::Line);
        if not TemplateFieldCaption.FindFirst then
            Error(Text008, SelectedField.Code);

        // Find the value of the selected field
        GetSelectedFieldValue(SelectedFieldDocumentValue, SelectedField, TempDocumentLine."Document No.", TempDocumentLine."Template No.");

        ResetField(SelectedField);

        // Setup field for column heading search
        SelectedField."Advanced Line Recognition Type" := SelectedField."Advanced Line Recognition Type"::FindFieldByColumnHeading;

        if SelectedFieldDocumentValue.Top < LineIdentFieldDocumentValue.Top then
            SelectedField."Field Position" := SelectedField."Field Position"::AboveAnchor
        else
            SelectedField."Field Position" := SelectedField."Field Position"::BelowAnchor;

        if SelectedField.Modify(true) then begin
            SetTemplateToALRProcessing(TempDocumentLine."Template No.");
            Message(Text007, SelectedField."Field Name", TemplateFieldCaption.Caption);
        end else
            Message(Text014);
    end;

    procedure SetToFieldSearchWithCaption(var TempDocumentLine: Record "CDC Temp. Document Line")
    var
        LineIdentFieldDocumentValue: Record "CDC Document Value";
        SelectedField: Record "CDC Template Field";
        SelectedFieldDocumentValue: Record "CDC Document Value";
        TemplateFieldCaption: Record "CDC Template Field Caption";
        DocumentPage: Record "CDC Document Page";
        CaptureEngine: Codeunit "ALR CDC Capture Engine";
    begin
        // Find field value of a normal position field
        GetLineIdentifierValue(LineIdentFieldDocumentValue, TempDocumentLine."Document No.", TempDocumentLine."Template No.");

        // Select field
        Message(Text016);
        if not SelectField(SelectedField, TempDocumentLine."Template No.", '') then
            Error(Text001);

        // Check that the selected field has at least one caption
        TemplateFieldCaption.SetRange("Template No.", SelectedField."Template No.");
        TemplateFieldCaption.SetRange(Code, SelectedField.Code);
        TemplateFieldCaption.SetRange(Type, TemplateFieldCaption.Type::Line);
        if not TemplateFieldCaption.FindFirst then
            Error(Text008, SelectedField.Code);

        // Find the value of the selected field
        GetSelectedFieldValue(SelectedFieldDocumentValue, SelectedField, TempDocumentLine."Document No.", TempDocumentLine."Template No.");

        ResetField(SelectedField);

        // 009 >>>
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
        // 009 <<<

        // Setup field for field search by caption
        SelectedField."Advanced Line Recognition Type" := SelectedField."Advanced Line Recognition Type"::FindFieldByCaptionInPosition;

        if SelectedFieldDocumentValue.Top < LineIdentFieldDocumentValue.Top then
            SelectedField."Field Position" := SelectedField."Field Position"::AboveAnchor
        else
            SelectedField."Field Position" := SelectedField."Field Position"::BelowAnchor;

        if SelectedField.Modify(true) then begin
            ;
            SetTemplateToALRProcessing(TempDocumentLine."Template No.");
            Message(Text017, SelectedField."Field Name");
        end else
            Message(Text014);
    end;

    procedure ResetFieldFromMenu(var TempDocumentLine: Record "CDC Temp. Document Line")
    var
        FieldToReset: Record "CDC Template Field";
    begin
        if SelectField(FieldToReset, TempDocumentLine."Template No.", '') then begin
            ResetField(FieldToReset);
            FieldToReset.Modify(true);
        end;
    end;

    local procedure ResetField(var TemplateField: Record "CDC Template Field")
    var
        cdctemplate: Record "CDC Template";
    begin
        // Reset the current field to default values
        with TemplateField do begin
            "Search for Value" := false;
            Required := false;
            Clear("Advanced Line Recognition Type");
            Clear("Anchor Field");
            Clear("Offset Top");
            Clear("Offset Bottom");
            Clear("Offset Left");
            Clear("Offset Right");
            Clear("Field Position");
            Clear(Sorting);
            Clear("Substitution Field");
            Clear("Get Value from Previous Value");
            Clear("ALR Typical Value Field Width");
            Clear("Typical Field Height");
            Clear("Caption Mandatory");
            Clear("ALR Value Caption Offset X");
            Clear("ALR Value Caption Offset Y");

            SetFilter("Advanced Line Recognition Type", '<>%1', "Advanced Line Recognition Type"::Default);
            if IsEmpty then
                if cdctemplate.Get(TemplateField."Template No.") then begin
                    if cdctemplate."Original Line Capt. Codeunit" <> 0 then begin
                        cdctemplate."Codeunit ID: Line Capture" := cdctemplate."Original Line Capt. Codeunit";
                        cdctemplate."Original Line Capt. Codeunit" := 0;
                        cdctemplate.Modify(true);
                    end;
                end;
        end;
    end;

    local procedure SelectField(var TemplateField: Record "CDC Template Field"; TemplateNo: Code[20]; ExcludedFieldsFilter: Text[250]): Boolean
    var
        lTemplateFieldList: Page "CDC Template Field List";
    begin
        with TemplateField do begin
            SetRange("Template No.", TemplateNo);
            SetRange(Type, Type::Line);
            if ExcludedFieldsFilter <> '' then
                SetFilter(Code, '<>%1', ExcludedFieldsFilter);
            lTemplateFieldList.SetTableView(TemplateField);
            lTemplateFieldList.LookupMode(true);
            if lTemplateFieldList.RunModal = ACTION::LookupOK then begin
                lTemplateFieldList.GetRecord(TemplateField);
                exit(true);
            end;
        end;
    end;

    procedure SetTemplateToALRProcessing(TemplateNo: Code[20])
    var
        lTemplate: Record "CDC Template";
    begin
        // Change Codeunit ID to the advanced line recognition codeunit on template
        if lTemplate.Get(TemplateNo) then begin
            if lTemplate."Codeunit ID: Line Capture" <> 61001 then begin
                lTemplate."Original Line Capt. Codeunit" := lTemplate."Codeunit ID: Line Capture";
                lTemplate.Validate("Codeunit ID: Line Capture", GetAdvLineRecCodeunit());
                lTemplate.Modify(true);
            end;
        end;
    end;

    local procedure GetAdvLineRecCodeunit(): Integer
    var
    begin
        exit(61001);
    end;

    local procedure GetLineIdentifierValue(var LineIdentFieldDocumentValue: Record "CDC Document Value"; DocumentNo: Code[20]; TemplateNo: Code[20])
    var
        LineIdentField: Record "CDC Template Field";
        LineIdentFieldFound: Boolean;
    begin
        with LineIdentField do begin
            SetRange("Template No.", TemplateNo);
            SetRange(Type, Type::Line);
            SetRange(Required, true);
            SetRange("Advanced Line Recognition Type", "Advanced Line Recognition Type"::Default);
            if FindSet then
                repeat
                    if LineIdentFieldDocumentValue.Get(DocumentNo, true, LineIdentField.Code, 1) then
                        if (LineIdentFieldDocumentValue."Template No." = TemplateNo) and
                           (LineIdentFieldDocumentValue.Type = LineIdentFieldDocumentValue.Type::Line)
                        then
                            LineIdentFieldFound := true;
                until (Next = 0) or LineIdentFieldFound;
        end;

        if not LineIdentFieldFound then
            Error(Text020);
    end;

    local procedure GetSelectedFieldValue(var SelectedFieldDocumentValue: Record "CDC Document Value"; SelectedField: Record "CDC Template Field"; DocumentNo: Code[20]; TemplateNo: Code[20])
    begin
        SelectedFieldDocumentValue.SetRange("Document No.", DocumentNo);
        SelectedFieldDocumentValue.SetRange("Is Value", true);
        SelectedFieldDocumentValue.SetRange(Code, SelectedField.Code);
        SelectedFieldDocumentValue.SetRange("Line No.", 0, 1);
        SelectedFieldDocumentValue.SetRange(Type, SelectedFieldDocumentValue.Type::Line);
        SelectedFieldDocumentValue.SetRange("Is Valid", true);
        SelectedFieldDocumentValue.SetRange("Template No.", TemplateNo);
        if not SelectedFieldDocumentValue.FindFirst then
            Error(Text004, SelectedField."Field Name", SelectedField.Code);  //value is mandatory
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
}

