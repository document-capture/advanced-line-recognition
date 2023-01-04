codeunit 61001 "ALR Advanced Line Capture"
{
    TableNo = "CDC Document";

    var
        TempMandatoryCDCTempDocumentField: Record "CDC Temp. Document Field" temporary;
        CDCTemplate: Record "CDC Template";
        CDCCaptureManagement: Codeunit "CDC Capture Management";
        ALRSingleInstanceMGt: Codeunit "ALR Single Instance Mgt.";
        NoMandatoryFieldsFoundLbl: Label 'You cannot use the advanced line recognition option %1 when the template does not have at least one line field marked as required!', Comment = 'Show when the template does not have at least one line field marked as required. %1 = selected ALR option', MaxLength = 999, Locked = false;

    trigger OnRun()
    begin
        //Reset template to standard line capture as we can now use an event
        if not CDCTemplate.Get(Rec."Template No.") then
            exit;

        CDCTemplate."Codeunit ID: Line Capture" := 6085716;
        CDCTemplate.Modify(true);

        Codeunit.Run(CDCTemplate."Codeunit ID: Line Capture", Rec);
    end;

    internal procedure RunLineCapture(CDCDocument: Record "CDC Document")
    var
        TempSortedCDCTempDocumentField: Record "CDC Temp. Document Field" temporary;
        TempCDCTempDocumentLine: Record "CDC Temp. Document Line" temporary;
        CDCTemplateField: Record "CDC Template Field";
        Handled: Boolean;
    begin
        //CleanupPrevValues(Document);
        if not CDCTemplate.Get(CDCDocument."Template No.") then
            exit;

        OnAfterStandardLineRecognition(CDCDocument, Handled);
        if Handled then
            exit;

        //BUILD TEMPORARY LINE TABLE AND LOOP LINES
        CDCDocument.BuildTempLinesTable(TempCDCTempDocumentLine);

        if TempCDCTempDocumentLine.FindSet() then begin
            FillSortedFieldBuffer(TempSortedCDCTempDocumentField, TempMandatoryCDCTempDocumentField, TempCDCTempDocumentLine);
            repeat
                TempSortedCDCTempDocumentField.SetCurrentKey("Document No.", "Sort Order");
                if TempSortedCDCTempDocumentField.FindSet() then
                    repeat
                        CDCTemplateField.Get(TempCDCTempDocumentLine."Template No.", CDCTemplateField.Type::Line, TempSortedCDCTempDocumentField."Field Code");
                        case CDCTemplateField."Advanced Line Recognition Type" of
                            CDCTemplateField."Advanced Line Recognition Type"::LinkedToAnchorField:
                                FindValueFromOffsetField(TempCDCTempDocumentLine, CDCTemplateField);
                            CDCTemplateField."Advanced Line Recognition Type"::FindFieldByCaptionInPosition:
                                FindValueByCaptionInPosition(TempCDCTempDocumentLine, CDCTemplateField, CDCDocument);
                            CDCTemplateField."Advanced Line Recognition Type"::FindFieldByColumnHeading:
                                FindFieldByColumnHeading(TempCDCTempDocumentLine, CDCTemplateField, CDCDocument);
                        end;
                    until TempSortedCDCTempDocumentField.Next() = 0;

                OnBeforeLineFinalProcessing(CDCDocument, TempCDCTempDocumentLine, Handled);

                if not Handled then begin
                    // Get source table values of header fields
                    GetSourceFieldValues(CDCDocument, TempCDCTempDocumentLine."Line No.");

                    // Get lookup field values of header fields
                    GetLookupFieldValue(CDCDocument, TempCDCTempDocumentLine."Line No.");

                    // Process fields that are still empty and look for 
                    EmptyValueProcessing(TempCDCTempDocumentLine);
                end;

                OnAfterLineFinalProcessing(CDCDocument, TempCDCTempDocumentLine);
                Clear(Handled);
            until TempCDCTempDocumentLine.Next() = 0;
            CleanupTempValues(CDCDocument);
        end;

        Handled := true;
    end;



    local procedure FindValueFromOffsetField(CDCTempDocumentLine: Record "CDC Temp. Document Line" temporary; var OffsetCDCTemplateField: Record "CDC Template Field")
    var
        CurrCDCDocumentPage: Record "CDC Document Page";
        CDCDocumentValue: Record "CDC Document Value";
        OffsetSourceCDCDocumentValue: Record "CDC Document Value";
        OffsetSourceCDCTemplateField: Record "CDC Template Field";
        CurrBottom: Integer;
        CurrLeft: Integer;
        CurrRight: Integer;
        CurrTop: Integer;
    begin
        //This function will capture the field value based on the offset/distance of a source field value

        //Get Line Identification Field Position
        if not OffsetSourceCDCTemplateField.Get(CDCTempDocumentLine."Template No.", OffsetSourceCDCTemplateField.Type::Line, OffsetCDCTemplateField."Linked Field") then
            exit;

        // Get current value record of offset source field
        if not OffsetSourceCDCDocumentValue.Get(CDCTempDocumentLine."Document No.", true, OffsetSourceCDCTemplateField.Code, CDCTempDocumentLine."Line No.") then
            exit;

        CurrCDCDocumentPage.Get(CDCTempDocumentLine."Document No.", OffsetSourceCDCDocumentValue."Page No.");

        // Create offset area for value capturing
        CurrTop := OffsetSourceCDCDocumentValue.Top + OffsetCDCTemplateField."Offset Top";
        CurrLeft := OffsetSourceCDCDocumentValue.Left + OffsetCDCTemplateField."Offset Left";
        CurrBottom := CurrTop + OffsetCDCTemplateField."Offset Bottom";
        CurrRight := CurrLeft + OffsetCDCTemplateField."Offset Right";
        CDCCaptureManagement.CaptureFromPos(CurrCDCDocumentPage, OffsetCDCTemplateField, CDCTempDocumentLine."Line No.", true, CurrTop, CurrLeft, CurrBottom, CurrRight, CDCDocumentValue);
        if CDCDocumentValue.Get(CDCTempDocumentLine."Document No.", true, OffsetCDCTemplateField.Code, CDCTempDocumentLine."Line No.") then
            if ((CDCDocumentValue."Value (Text)" = '') and (CDCDocumentValue."Value (Decimal)" = 0)) or (not CDCDocumentValue."Is Valid") then
                CDCDocumentValue.Delete();

    end;

    local procedure FindValueByCaptionInPosition(var CDCTempDocumentLine: Record "CDC Temp. Document Line" temporary; var CurrCDCTemplateField: Record "CDC Template Field"; CDCDocument: Record "CDC Document"): Boolean
    var
        CurrCDCDocumentPage: Record "CDC Document Page";
        CDCDocumentValue: Record "CDC Document Value";
        CDCDocumentValueCopy: Record "CDC Document Value";
        CDCCaptureEngine: Codeunit "CDC Capture Engine";
        FromTopPage: Integer;
        FromTopPos: Integer;
        i: Integer;
        ToBottomPage: Integer;
        ToBottomPos: Integer;
        Word: Text[1024];
    begin
        // We cannot proceed if there is no line field in the template defined as required=true
        if TempMandatoryCDCTempDocumentField.Count = 0 then
            error(NoMandatoryFieldsFoundLbl, CurrCDCTemplateField."Advanced Line Recognition Type");


        if not CDCDocument.Get(CDCTempDocumentLine."Document No.") then
            exit;

        //Delete current value
        if CDCDocumentValue.Get(CDCTempDocumentLine."Document No.", true, CurrCDCTemplateField.Code, CDCTempDocumentLine."Line No.") then
            CDCDocumentValue.Delete();

        // Get valid range depended of search direction
        // 1. above the standard recognized line: range is between standard standard line and previous line
        // 2. below the standard recognized line: range is between standard standard line and next line
        if (CurrCDCTemplateField."Field value position" = CurrCDCTemplateField."Field value position"::AboveStandardLine) then
            GetRangeToPrevLine(CDCDocument, CDCTempDocumentLine, FromTopPage, FromTopPos, ToBottomPage, ToBottomPos)
        else
            GetRangeToNextLine(CDCDocument, CDCTempDocumentLine, FromTopPage, FromTopPos, ToBottomPage, ToBottomPos);

        if (FromTopPage > 0) and (ToBottomPage > 0) then   //there are some situations where the system couldn't find the range
            for i := FromTopPage to ToBottomPage do begin
                if not CurrCDCDocumentPage.Get(CDCTempDocumentLine."Document No.", i) then
                    exit;

                CurrCDCTemplateField."Caption Offset X" := CurrCDCTemplateField."ALR Value Caption Offset X";
                CurrCDCTemplateField."Caption Offset Y" := CurrCDCTemplateField."ALR Value Caption Offset Y";
                CurrCDCTemplateField."Typical Field Width" := CurrCDCTemplateField."ALR Typical Value Field Width";

                // set the line region
                if i < ToBottomPage then
                    ALRSingleInstanceMGt.SetLineRegion(CDCTempDocumentLine."Document No.", i, FromTopPos, i, CurrCDCDocumentPage."Bottom Word Pos.")
                else
                    if (i > FromTopPage) and (i < ToBottomPage) then
                        ALRSingleInstanceMGt.SetLineRegion(CDCTempDocumentLine."Document No.", i, 0, i, CurrCDCDocumentPage."Bottom Word Pos.")
                    else
                        if FromTopPos > ToBottomPos then
                            ALRSingleInstanceMGt.SetLineRegion(CDCTempDocumentLine."Document No.", i, 0, i, ToBottomPos)
                        else
                            ALRSingleInstanceMGt.SetLineRegion(CDCTempDocumentLine."Document No.", i, FromTopPos, i, ToBottomPos);

                // Find value in predefined line region
                Word := CDCCaptureEngine.CaptureField(CDCDocument, CurrCDCDocumentPage."Page No.", CurrCDCTemplateField, false);

                if Word <> '' then begin
                    if (CDCDocumentValue.Get(CDCDocument."No.", true, CurrCDCTemplateField.Code, 0)) then begin
                        CDCDocumentValueCopy := CDCDocumentValue;
                        CDCDocumentValueCopy."Line No." := CDCTempDocumentLine."Line No.";
                        CDCDocumentValueCopy.Type := CDCDocumentValueCopy.Type::Line;
                        CDCDocumentValueCopy.Insert();
                        CDCDocumentValue.Delete();
                    end;
                    CDCCaptureManagement.UpdateFieldValue(CDCDocument."No.", CDCTempDocumentLine."Page No.", CDCTempDocumentLine."Line No.", CurrCDCTemplateField, Word, false, false);

                    exit(true);
                end;
            end;
    end;

    local procedure FindFieldByColumnHeading(var CDCTempDocumentLine: Record "CDC Temp. Document Line" temporary; var CurrCDCTemplateField: Record "CDC Template Field"; CDCDocument: Record "CDC Document")
    var
        CaptionCDCDocumentPage: Record "CDC Document Page";
        CurrCDCDocumentPage: Record "CDC Document Page";
        CaptionCDCDocumentValue: Record "CDC Document Value";
        CDCDocumentValue: Record "CDC Document Value";
        CDCDocumentValueNew: Record "CDC Document Value";
        TempCDCDocumentValue: Record "CDC Document Value" temporary;
        CaptionEndCDCDocumentWord: array[100] of Record "CDC Document Word";
        CaptionStartCDCDocumentWord: array[100] of Record "CDC Document Word";
        CaptionFound: Boolean;
        PageStop: Boolean;
        Bottom: Integer;
        CaptionPageNo: Integer;
        FieldLeft: Integer;
        FieldWidth: Integer;
        FromTopPage: Integer;
        FromTopPos: Integer;
        LastFoundLineNo: Integer;
        LineHeight: Integer;
        LineNo: Integer;
        NewBottom: Integer;
        Right: Integer;
        ToBottomPage: Integer;
        ToBottomPos: Integer;
        Top: Integer;
    begin
        // We cannot proceed if there is no line field in the template defined as required=true
        if TempMandatoryCDCTempDocumentField.Count = 0 then
            error(NoMandatoryFieldsFoundLbl, CurrCDCTemplateField."Advanced Line Recognition Type");

        //This function will capture the field value based on a column heading, actualy like the default line recognition but filtered on the area between the prev. and next line
        if not CDCDocument.Get(CDCTempDocumentLine."Document No.") then
            exit;

        if not CDCTemplate.Get(CDCTempDocumentLine."Template No.") then
            exit;

        // Delete old values
        if CDCDocumentValue.Get(CDCTempDocumentLine."Document No.", true, CurrCDCTemplateField.Code, CDCTempDocumentLine."Line No.") then
            CDCDocumentValue.Delete();

        // Find the Caption position on current or previous pages
        CaptionPageNo := CDCTempDocumentLine."Page No.";
        repeat
            CaptionFound := GetStartAndEndCaption(CaptionStartCDCDocumentWord, CaptionEndCDCDocumentWord, CurrCDCTemplateField, CDCTempDocumentLine."Document No.", CaptionPageNo);
            if not CaptionFound then
                CaptionPageNo -= 1;
        until (CaptionPageNo = 0) or CaptionFound;

        if (not CaptionFound) then
            exit;

        if not CaptionCDCDocumentPage.Get(CDCTempDocumentLine."Document No.", CaptionPageNo) then
            exit;

        GetPositionOfCaption(CaptionCDCDocumentPage, CurrCDCTemplateField, CaptionStartCDCDocumentWord[1], CaptionEndCDCDocumentWord[1], CaptionCDCDocumentValue, FieldLeft, FieldWidth, Bottom, Top);

        // Get position of next or previous line
        if (CurrCDCTemplateField."Field value position" = CurrCDCTemplateField."Field value position"::AboveStandardLine) then begin
            GetRangeToPrevLine(CDCDocument, CDCTempDocumentLine, FromTopPage, FromTopPos, ToBottomPage, ToBottomPos);
            if FromTopPos > Top then
                Top := FromTopPos;
        end else begin
            GetRangeToNextLine(CDCDocument, CDCTempDocumentLine, FromTopPage, FromTopPos, ToBottomPage, ToBottomPos);
            Top := FromTopPos;
        end;

        NewBottom := 0;
        LineNo := 1000 * CDCTempDocumentLine."Page No.";
        LineHeight := 12;


        Bottom := Top + LineHeight;

        PageStop := false;
        if not CurrCDCDocumentPage.Get(CDCTempDocumentLine."Document No.", FromTopPage) then
            exit;
        repeat
            LineNo += 1;
            Right := FieldLeft + FieldWidth;
            NewBottom := CaptureTableCell(CDCTemplate, CurrCDCDocumentPage, CurrCDCTemplateField, LineNo, Top, FieldLeft, Bottom, Right);
            if NewBottom > 0 then begin
                if NewBottom > Bottom then
                    Bottom := NewBottom;

                if not IsFieldValid(CurrCDCTemplateField, CDCDocument, LineNo) then begin
                    CDCDocumentValue.Reset();
                    CDCDocumentValue.SetRange("Document No.", CDCDocument."No.");
                    CDCDocumentValue.SetRange("Line No.", LineNo);
                    CDCDocumentValue.DeleteAll(true);
                end else begin

                    LastFoundLineNo := LineNo;
                    // Stop search, when search direction is upwards from standard line
                    PageStop := (CurrCDCTemplateField."Field value search direction" = CurrCDCTemplateField."Field value search direction"::Downwards);
                    if CDCDocumentValue.Get(CDCTempDocumentLine."Document No.", true, CurrCDCTemplateField.Code, LastFoundLineNo) then begin
                        TempCDCDocumentValue := CDCDocumentValue;
                        TempCDCDocumentValue.Insert();
                        CDCDocumentValue.Delete();
                    end;
                end;
            end;

            if not PageStop then begin
                Top := Bottom;
                Bottom := Top + LineHeight;

                if (Bottom > CurrCDCDocumentPage."Bottom Word Pos.") and (CurrCDCDocumentPage."Page No." < ToBottomPage) then begin
                    //New page - some variables must be reset
                    CurrCDCDocumentPage.Get(CurrCDCDocumentPage."Document No.", CurrCDCDocumentPage."Page No." + 1);
                    CaptionPageNo := CurrCDCDocumentPage."Page No.";
                    LineNo := 1000 * CurrCDCDocumentPage."Page No.";
                    if GetStartAndEndCaption(CaptionStartCDCDocumentWord, CaptionEndCDCDocumentWord, CurrCDCTemplateField, CDCTempDocumentLine."Document No.", CaptionPageNo) then begin
                        CaptionCDCDocumentPage.Get(CDCTempDocumentLine."Document No.", CurrCDCDocumentPage."Page No.");
                        if GetPositionOfCaption(CaptionCDCDocumentPage, CurrCDCTemplateField, CaptionStartCDCDocumentWord[1], CaptionEndCDCDocumentWord[1], CaptionCDCDocumentValue, FieldLeft, FieldWidth, Bottom, Top) then
                            Bottom := Top + LineHeight;

                    end;
                end else
                    if (Bottom > CurrCDCDocumentPage."Bottom Word Pos.") or ((Bottom > ToBottomPos) and (CurrCDCDocumentPage."Page No." = ToBottomPage)) then
                        PageStop := true;
            end;
        until PageStop;

        //Zeilennr. speichern
        if TempCDCDocumentValue.Get(CDCTempDocumentLine."Document No.", true, CurrCDCTemplateField.Code, LastFoundLineNo) then begin
            CDCDocumentValueNew := TempCDCDocumentValue;
            CDCDocumentValueNew."Line No." := CDCTempDocumentLine."Line No.";
            CDCDocumentValueNew.Insert();
            TempCDCDocumentValue.Delete();
            CDCCaptureManagement.UpdateFieldValue(CDCTempDocumentLine."Document No.", CDCTempDocumentLine."Page No.", CDCTempDocumentLine."Line No.", CurrCDCTemplateField, CDCDocumentValueNew."Value (Text)", false, false);
        end;
    end;

    local procedure EmptyValueProcessing(var CDCTempDocumentLine: Record "CDC Temp. Document Line")
    var
        CDCDocumentValue: Record "CDC Document Value";
        CDCTemplateField: Record "CDC Template Field";
        LineDeleted: Boolean;
    begin
        CDCTemplateField.SetRange("Template No.", CDCTempDocumentLine."Template No.");
        CDCTemplateField.SetRange(Type, CDCTemplateField.Type::Line);
        CDCTemplateField.SetFilter("Empty value handling", '>%1', CDCTemplateField."Empty value handling"::Ignore);
        if CDCTemplateField.IsEmpty then
            exit;

        if CDCTemplateField.FindSet() then
            repeat
                if not CDCDocumentValue.Get(CDCTempDocumentLine."Document No.", true, CDCTemplateField.Code, CDCTempDocumentLine."Line No.") then
                    case CDCTemplateField."Empty value handling" of

                        "ALR Empty Field Value Handling"::CopyPrevLineValue:
                            SetValueFromPreviousLineValue(CDCTempDocumentLine, CDCTemplateField);
                        "ALR Empty Field Value Handling"::CopyHeaderFieldValue,
                        "ALR Empty Field Value Handling"::CopyLineFieldValue:
                            if CDCTemplateField."Replacement Field" <> '' then
                                SetValueFromReplacementFieldValue(CDCTempDocumentLine, CDCTemplateField);
                        "ALR Empty Field Value Handling"::FixedValue:
                            if CDCTemplateField."Fixed Replacement Value" <> '' then
                                SetValueFromFixedReplacementValue(CDCTempDocumentLine, CDCTemplateField);
                        "ALR Empty Field Value Handling"::DeleteLine:
                            LineDeleted := DeleteEmptyValueLine(CDCTempDocumentLine);
                    end;
            until (CDCTemplateField.Next() = 0) or (LineDeleted);
    end;

    local procedure SetValueFromFixedReplacementValue(var
                                                          CDCTempDocumentLine: Record "CDC Temp. Document Line" temporary;
                                                          CDCTemplateField: Record "CDC Template Field")
    begin
        CDCCaptureManagement.UpdateFieldValue(CDCTempDocumentLine."Document No.", CDCTempDocumentLine."Page No.", CDCTempDocumentLine."Line No.", CDCTemplateField, CDCTemplateField."Fixed Replacement Value", false, false);
    end;

    local procedure SetValueFromReplacementFieldValue(var CDCTempDocumentLine: Record "CDC Temp. Document Line"; CDCTemplateField: Record "CDC Template Field")
    var
        CDCDocumentValue: Record "CDC Document Value";
        SubstitutionCDCDocumentValue: Record "CDC Document Value";
        SubstitutionCDCTemplateField: Record "CDC Template Field";
        TempLineNo: Integer;
    begin
        if CDCTemplateField."Empty value handling" = CDCTemplateField."Empty value handling"::CopyHeaderFieldValue then begin
            if not SubstitutionCDCTemplateField.Get(CDCTempDocumentLine."Template No.", SubstitutionCDCTemplateField.Type::Header, CDCTemplateField."Replacement Field") then
                exit;

            TempLineNo := 0; // Header fields have line no = 0
        end else begin
            if not SubstitutionCDCTemplateField.Get(CDCTempDocumentLine."Template No.", SubstitutionCDCTemplateField.Type::Line, CDCTemplateField."Replacement Field") then
                exit;

            TempLineNo := CDCTempDocumentLine."Line No.";
        end;

        if SubstitutionCDCDocumentValue.Get(CDCTempDocumentLine."Document No.", true, SubstitutionCDCTemplateField.Code, TempLineNo) then begin
            CDCCaptureManagement.UpdateFieldValue(CDCTempDocumentLine."Document No.", CDCTempDocumentLine."Page No.", CDCTempDocumentLine."Line No.", CDCTemplateField, SubstitutionCDCDocumentValue."Value (Text)", false, false);
            if CDCDocumentValue.Get(CDCTempDocumentLine."Document No.", true, CDCTemplateField.Code, CDCTempDocumentLine."Line No.") then begin
                // Set positions of replacement value to show rectangles in preview window
                CDCDocumentValue.Top := SubstitutionCDCDocumentValue.Top;
                CDCDocumentValue.Bottom := SubstitutionCDCDocumentValue.Bottom;
                CDCDocumentValue.Left := SubstitutionCDCDocumentValue.Left;
                CDCDocumentValue.Right := SubstitutionCDCDocumentValue.Right;
                CDCDocumentValue.Modify();
            end;
        end;
    end;

    local procedure SetValueFromPreviousLineValue(var CDCTempDocumentLine: Record "CDC Temp. Document Line"; CDCTemplateField: Record "CDC Template Field")
    var
        CDCDocumentValue: Record "CDC Document Value";
    begin
        if CDCDocumentValue.Get(CDCTempDocumentLine."Document No.", true, CDCTemplateField.Code, CDCTempDocumentLine."Line No." - 1) then
            CDCCaptureManagement.UpdateFieldValue(CDCTempDocumentLine."Document No.", CDCTempDocumentLine."Page No.", CDCTempDocumentLine."Line No.", CDCTemplateField, CDCDocumentValue."Value (Text)", false, false);
    end;

    local procedure DeleteEmptyValueLine(var CDCTempDocumentLine: Record "CDC Temp. Document Line"): Boolean
    var
        CDCDocumentValue: Record "CDC Document Value";
    begin
        CDCDocumentValue.SetRange("Document No.", CDCTempDocumentLine."Document No.");
        CDCDocumentValue.SetRange(Type, CDCDocumentValue.Type::Line);
        CDCDocumentValue.SetRange("Line No.", CDCTempDocumentLine."Line No.");
        CDCDocumentValue.DeleteAll(true);

        exit(CDCTempDocumentLine.Delete(true));
    end;

    internal procedure FindAllPONumbersInDocument(var CDCDocument: Record "CDC Document")
    var
        CDCDocumentWord: Record "CDC Document Word";
        CDCDocumentValue: Record "CDC Document Value";
        CDCTemplateField: Record "CDC Template Field";
        PurchaseHeader: Record "Purchase Header";
        TempPurchaseHeader: Record "Purchase Header" temporary;
        CDCModuleLicense: Codeunit "CDC Module License";
        FoundPurchaseOrders: text;
    begin
        if not CDCModuleLicense.IsMatchingActivated(false) then
            exit;

        if not CDCTemplate.GET(CDCDocument."Template No.") then
            exit;

        if ((NOT CDCTemplate."Auto PO search") OR (StrLen(CDCTemplate."Auto PO search filter") < 2)) then
            exit;

        // Get order no. field first.
        if not CDCTemplateField.GET(CDCDocument."Template No.", CDCTemplateField.Type::Header, 'OURDOCNO') then
            exit;

        CDCDocumentWord.SETRANGE("Document No.", CDCDocument."No.");

        // Iterate through Document Word table and filter for our PO number filter string
        CDCDocumentWord.SetFilter(Word, CDCTemplate."Auto PO search filter");
        if CDCDocumentWord.FindSet() then
            repeat
                // Check if there is a PO in the system with the matched word
                IF PurchaseHeader.GET(PurchaseHeader."Document Type"::Order, CopyStr(UPPERCASE(CDCDocumentWord.Word), 1, MAXSTRLEN(PurchaseHeader."No."))) THEN
                    // Check if the number exists in the temp. PO buffer
                    if not TempPurchaseHeader.GET(PurchaseHeader."Document Type", PurchaseHeader."No.") then begin
                        TempPurchaseHeader := PurchaseHeader;
                        TempPurchaseHeader.Insert();
                    end;
            until CDCDocumentWord.Next() = 0;

        // Iterate through all found PO's and create the string, that can be used for order matching
        if TempPurchaseHeader.FindSet() then
            repeat
                if (STRLEN(FoundPurchaseOrders) + STRLEN(TempPurchaseHeader."No.") + 1) <= MAXSTRLEN(CDCDocumentValue."Value (Text)") then begin
                    if (STRLEN(FoundPurchaseOrders) > 0) then
                        FoundPurchaseOrders += ',';
                    FoundPurchaseOrders += TempPurchaseHeader."No.";
                END;
            until TempPurchaseHeader.Next() = 0;

        CDCTemplateField.GET(CDCDocument."Template No.", CDCTemplateField.Type::Header, 'OURDOCNO');
        CDCCaptureManagement.UpdateFieldValue(CDCDocument."No.", 0, 0, CDCTemplateField, FoundPurchaseOrders, FALSE, FALSE);
    end;

    internal procedure ApplyAdvancedStringFunctions(CDCTemplateField: Record "CDC Template Field"; var Word: Text[1024])
    var
    begin
        if CDCTemplateField."Enable DelChr" then begin
            if (CDCTemplateField."Characters to delete" = '') then
                CDCTemplateField."Characters to delete" := ' ';

            case
                CDCTemplateField."Pos. of characters" of
                CDCTemplateField."Pos. of characters"::All:
                    Word := DelChr(Word, '=', CDCTemplateField."Characters to delete");
                CDCTemplateField."Pos. of characters"::Leading:
                    Word := DelChr(Word, '<', CDCTemplateField."Characters to delete");
                CDCTemplateField."Pos. of characters"::Trailing:
                    Word := DelChr(Word, '>', CDCTemplateField."Characters to delete");
            end;
        end;

        if (CDCTemplateField."Extract string by CopyStr") and (CDCTemplateField."CopyStr Pos" > 0) then
            if CDCTemplateField."CopyStr Length" = 0 then
                Word := CopyStr(Word, CDCTemplateField."CopyStr Pos", MaxStrLen(Word))
            else
                Word := CopyStr(CopyStr(Word, CDCTemplateField."CopyStr Pos", CDCTemplateField."CopyStr Length"), 1, MaxStrLen(Word));
    end;

    internal procedure GetSourceFieldValues(var CDCDocument: Record "CDC Document"; LineNo: Integer)
    var
        CDCDocumentCategory: Record "CDC Document Category";
        CDCTemplateField: Record "CDC Template Field";
        CDCRecordIDMgt: Codeunit "CDC Record ID Mgt.";
        SourceRecordId: RecordId;
        SourceRecordRef: RecordRef;
        SourceRecFieldRef: FieldRef;
        Word: Text[1024];
    begin
        CDCTemplateField.SetRange("Template No.", CDCDocument."Template No.");

        if LineNo = 0 then
            CDCTemplateField.SetRange(Type, CDCTemplateField.Type::Header)
        else
            CDCTemplateField.SetRange(Type, CDCTemplateField.Type::Line);

#pragma warning disable AA0210
        CDCTemplateField.SetFilter("Get value from source field", '>0');
#pragma warning restore AA0210
        if CDCTemplateField.IsEmpty then
            exit;

        if not CDCTemplate.Get(CDCDocument."Template No.") then
            exit;

        if not CDCDocumentCategory.Get(CDCTemplate."Category Code") then
            exit;

        if not CDCRecordIDMgt.GetRecIDFromTreeID(CDCDocument."Source Record ID Tree ID", SourceRecordId) then
            exit;

        if not SourceRecordRef.Get(SourceRecordId) then
            exit;

        CDCTemplateField.FindSet();
        repeat
            SourceRecFieldRef := SourceRecordRef.Field(CDCTemplateField."Get value from source field");
            Word := CopyStr(Format(SourceRecFieldRef.Value), 1, MaxStrLen(Word));
            ApplyAdvancedStringFunctions(CDCTemplateField, Word);
            if Word <> '' then
                CDCCaptureManagement.UpdateFieldValue(CDCDocument."No.", 1, LineNo, CDCTemplateField, Word, false, false)
        until CDCTemplateField.Next() = 0;
    end;

    //
    internal procedure GetLookupFieldValue(var CDCDocument: Record "CDC Document"; LineNo: Integer)
    var
        CDCTableFilterField: Record "CDC Table Filter Field";
        CDCTemplateField: Record "CDC Template Field";
        SourceRecordRef: RecordRef;
        SourceFieldRef: FieldRef;
        Word: Text[1024];
    begin
        CDCTemplateField.SetRange("Template No.", CDCDocument."Template No.");
        if LineNo = 0 then
            CDCTemplateField.SetRange(Type, CDCTemplateField.Type::Header)
        else
            CDCTemplateField.SetRange(Type, CDCTemplateField.Type::Line);

        CDCTemplateField.SetRange("Get value from lookup", true);
        if CDCTemplateField.IsEmpty then
            exit;

        if CDCTemplateField.FindSet() then
            repeat
                CDCTableFilterField.SETRANGE("Table Filter GUID", CDCTemplateField."Source Table Filter GUID");
                if CDCTableFilterField.IsEmpty then
                    exit;

                SourceRecordRef.Open(CDCTemplateField."Source Table No.");
                SourceFieldRef := SourceRecordRef.Field(CDCTableFilterField."Field No.");
                if SetLookupFieldFilter(SourceRecordRef, CDCTemplateField, CDCDocument, LineNo) then begin
                    SourceFieldRef := SourceRecordRef.Field(CDCTemplateField."Source Field No.");
                    Word := CopyStr(SourceFieldRef.Value, 1, MaxStrLen(Word));
                    ApplyAdvancedStringFunctions(CDCTemplateField, Word);
                    CDCCaptureManagement.UpdateFieldValue(CDCDocument."No.", 1, LineNo, CDCTemplateField, Word, false, false);
                end;
            until CDCTemplateField.Next() = 0;
    end;

    internal procedure SetLookupFieldFilter(var LookupRecordRef: RecordRef; CDCTemplateField: Record "CDC Template Field"; CDCDocument: Record "CDC Document"; LineNo: Integer): Boolean  // LookupRecID: Record "CDC Temp. Lookup Record ID"
    var
        CDCTableFilterField: Record "CDC Table Filter Field";
        LookupCDCTemplateField: Record "CDC Template Field";
        FieldRef: FieldRef;
        Values: Text[250];
    begin
        CDCTableFilterField.SETRANGE("Table Filter GUID", CDCTemplateField."Source Table Filter GUID");
        IF CDCTableFilterField.FindSet() THEN
            REPEAT
                FieldRef := LookupRecordRef.FIELD(CDCTableFilterField."Field No.");
                IF CDCTableFilterField."Filter Type" = CDCTableFilterField."Filter Type"::"Fixed Filter" THEN BEGIN
                    CDCTableFilterField.GetValues(Values, CDCTableFilterField."Filter Type");
                    FieldRef.SETFILTER(Values);
                END ELSE
                    IF LookupCDCTemplateField.GET(CDCTableFilterField."Template No.", CDCTableFilterField."Template Field Type",
                      CDCTableFilterField."Template Field Code")
                    THEN
                        FieldRef.SETFILTER(CDCCaptureManagement.GetValueAsText(CDCDocument."No.", LineNo, LookupCDCTemplateField));
            UNTIL CDCTableFilterField.Next() = 0;

        EXIT(LookupRecordRef.FindSet());
    end;

    local procedure GetRangeToNextLine(CDCDocument: Record "CDC Document"; var CDCTempDocumentLine: Record "CDC Temp. Document Line"; var SearchFromPage: Integer; var SearchFromPos: Integer; var SearchToPage: Integer; var SearchToPos: Integer)
    var
        CurrCDCDocumentPage: Record "CDC Document Page";
        CDCDocumentValue: Record "CDC Document Value";
        StopPos: array[100] of Integer;
    begin
        // This function calculates the range until the next position/line
        Clear(SearchFromPage);
        Clear(SearchFromPos);
        Clear(SearchToPage);
        Clear(SearchToPos);

        CDCDocumentValue.SetCurrentKey(CDCDocumentValue."Document No.", CDCDocumentValue."Is Value", CDCDocumentValue.Code, CDCDocumentValue."Line No.");
        CDCDocumentValue.SetRange(CDCDocumentValue."Document No.", CDCDocument."No.");
        CDCDocumentValue.SetRange(CDCDocumentValue."Is Value", true);
        CDCDocumentValue.SetRange(CDCDocumentValue.Type, CDCDocumentValue.Type::Line);
        CDCDocumentValue.SetFilter(CDCDocumentValue."Page No.", '>%1', 0);

        GetCurrLinePosition(CDCDocumentValue, CDCTempDocumentLine."Line No.", SearchFromPage, SearchFromPos, SearchToPage, SearchToPos);
        // Filter for next line
        CDCDocumentValue.SetRange(CDCDocumentValue."Line No.", CDCTempDocumentLine."Line No." + 1);
        if CDCDocumentValue.FindSet() then
            repeat
                if (SearchToPage < CDCDocumentValue."Page No.") or (SearchToPage = 0) then begin
                    SearchToPage := CDCDocumentValue."Page No.";
                    SearchToPos := 0;
                end;

                if SearchToPage = CDCDocumentValue."Page No." then
                    if (SearchToPos < CDCDocumentValue.Top) or (SearchToPos = 0) then
                        SearchToPos := CDCDocumentValue.Top;

            until CDCDocumentValue.Next() = 0
        else begin
            // As there is no next line, calculate to next header value or bottom of current page
            CDCDocumentValue.SetCurrentKey(CDCDocumentValue."Document No.", CDCDocumentValue."Is Value", CDCDocumentValue.Code, CDCDocumentValue."Line No.");
            CDCDocumentValue.SetRange(CDCDocumentValue."Document No.", CDCDocument."No.");
            CDCDocumentValue.SetRange(CDCDocumentValue."Is Value", false);
            CDCDocumentValue.SetRange(CDCDocumentValue.Type, CDCDocumentValue.Type::Header);
            CDCDocumentValue.SetRange(CDCDocumentValue."Page No.", SearchToPage);
            CDCDocumentValue.SetFilter(CDCDocumentValue.Top, '>%1', SearchToPos);
            CDCDocumentValue.SetRange(CDCDocumentValue."Line No.", 0);
            if CDCDocumentValue.FindSet(false, false) then begin
                if CDCDocumentValue."Page No." > SearchToPage then
                    SearchToPage := CDCDocumentValue."Page No.";

                SearchToPos := CDCDocumentValue.Top
            end else begin
                CDCDocumentValue.SetFilter(CDCDocumentValue."Page No.", '>%1', SearchToPage);
                CDCDocumentValue.SetRange(CDCDocumentValue.Top);
                if CDCDocumentValue.FindFirst() then begin
                    if CDCDocumentValue."Page No." > SearchToPage then
                        SearchToPage := CDCDocumentValue."Page No.";

                    SearchToPos := CDCDocumentValue.Top
                end else begin
                    CurrCDCDocumentPage.Get(CDCDocument."No.", SearchToPage);
                    SearchToPos := CurrCDCDocumentPage."Bottom Word Pos.";
                end;
            end;


            GetStopLineRecognitionPositions(StopPos, SearchToPage, CDCDocument);
            if (StopPos[SearchToPage] > 0) and (StopPos[SearchToPage] <= SearchToPos) then
                SearchToPos := StopPos[SearchToPage];
        end;
    end;

    local procedure GetRangeToPrevLine(CDCDocument: Record "CDC Document"; var CDCTempDocumentLine: Record "CDC Temp. Document Line"; var RangeTopPage: Integer; var RangeTopPos: Integer; var RangeBottomPage: Integer; var RangeBottomPos: Integer)
    var
        CDCDocumentValue: Record "CDC Document Value";
        CurrLineBottomPage: Integer;
        CurrLineBottomPos: Integer;
        CurrLineTopPage: Integer;
        CurrLineTopPos: Integer;
        PrevLineBottomPage: Integer;
        PrevLineBottomPos: Integer;
        PrevLineTopPage: Integer;
        PrevLineTopPos: Integer;
    begin
        // This function calculates the range until the previous position/line
        Clear(PrevLineTopPage);
        Clear(PrevLineTopPos);
        Clear(PrevLineBottomPage);
        Clear(PrevLineBottomPos);

        CDCDocumentValue.SetCurrentKey(CDCDocumentValue."Document No.", CDCDocumentValue."Is Value", CDCDocumentValue.Code, CDCDocumentValue."Line No.");
        CDCDocumentValue.SetRange(CDCDocumentValue."Document No.", CDCDocument."No.");
        CDCDocumentValue.SetRange(CDCDocumentValue."Is Value", true);
        CDCDocumentValue.SetRange(CDCDocumentValue.Type, CDCDocumentValue.Type::Line);
        CDCDocumentValue.SetFilter(CDCDocumentValue."Page No.", '>%1', 0);

        GetCurrLinePosition(CDCDocumentValue, CDCTempDocumentLine."Line No.", CurrLineTopPage, CurrLineTopPos, CurrLineBottomPage, CurrLineBottomPos);
        // Filter for Prev line
        CDCDocumentValue.SetRange(CDCDocumentValue."Line No.", CDCTempDocumentLine."Line No." - 1);
        if CDCDocumentValue.FindSet() then
            repeat
                if (CDCDocumentValue."Page No." < PrevLineTopPage) or (PrevLineTopPage = 0) then begin
                    PrevLineTopPage := CDCDocumentValue."Page No.";
                    Clear(PrevLineTopPos);
                end;

                if (CDCDocumentValue."Page No." > PrevLineBottomPage) or (PrevLineBottomPage = 0) then begin
                    PrevLineBottomPage := CDCDocumentValue."Page No.";
                    Clear(PrevLineBottomPos);
                end;

                if PrevLineTopPage = CDCDocumentValue."Page No." then
                    if (CDCDocumentValue.Top < PrevLineTopPos) or (PrevLineTopPos = 0) then
                        PrevLineTopPos := CDCDocumentValue.Top;

                if PrevLineBottomPage = CDCDocumentValue."Page No." then
                    if (CDCDocumentValue.Bottom > PrevLineBottomPos) or (PrevLineBottomPos = 0) then
                        PrevLineBottomPos := CDCDocumentValue.Bottom;
            until CDCDocumentValue.Next() = 0
        else begin
            // As there is no Prev line, calculate to Prev header value or bottom of current page
            CDCDocumentValue.SetCurrentKey(CDCDocumentValue."Document No.", CDCDocumentValue."Is Value", CDCDocumentValue.Code, CDCDocumentValue."Line No.");
            CDCDocumentValue.SetRange(CDCDocumentValue."Document No.", CDCDocument."No.");
            CDCDocumentValue.SetRange(CDCDocumentValue."Is Value", false);
            CDCDocumentValue.SetRange(CDCDocumentValue.Type, CDCDocumentValue.Type::Header);
            CDCDocumentValue.SetFilter(CDCDocumentValue."Page No.", '<=%1', CDCDocumentValue."Page No.");
            CDCDocumentValue.SetFilter(CDCDocumentValue.Top, '<%1', CurrLineTopPos);
            if CDCDocumentValue.FindFirst() then begin
                PrevLineBottomPos := CDCDocumentValue.Bottom;
                PrevLineBottomPage := CDCDocumentValue."Page No.";
            end else begin
                PrevLineBottomPos := 0;
                PrevLineBottomPage := CurrLineTopPage;
            end;
        end;

        RangeTopPage := PrevLineBottomPage;
        RangeBottomPage := CurrLineTopPage;
        RangeTopPos := PrevLineBottomPos + 1;
        //RangeBottomPos := CurrLineTopPos - 1;
        RangeBottomPos := CurrLineBottomPos - 1;

    end;

    local procedure GetCurrLinePosition(var CDCDocumentValue: Record "CDC Document Value"; LineNo: Integer; var CurrLineTopPage: Integer; var CurrLineTopPos: Integer; var CurrLineBottomPage: Integer; var CurrLineBottomPos: Integer)
    begin
        // Filter for current line
        CDCDocumentValue.SetRange(CDCDocumentValue."Line No.", LineNo);
        if CDCDocumentValue.FindSet() then
            repeat
                if TempMandatoryCDCTempDocumentField.Get(CDCDocumentValue.GetFilter("Document No."), CDCDocumentValue.Code) then begin
                    if (CDCDocumentValue."Page No." < CurrLineTopPage) or (CurrLineTopPage = 0) then begin
                        CurrLineTopPage := CDCDocumentValue."Page No.";
                        Clear(CurrLineTopPos);
                    end;

                    if (CDCDocumentValue."Page No." > CurrLineBottomPage) or (CurrLineBottomPage = 0) then begin
                        CurrLineBottomPage := CDCDocumentValue."Page No.";
                        Clear(CurrLineBottomPos);
                    end;

                    if CurrLineTopPage = CDCDocumentValue."Page No." then
                        if (CDCDocumentValue.Top < CurrLineTopPos) or (CurrLineTopPos = 0) then
                            CurrLineTopPos := CDCDocumentValue.Top;

                    if CurrLineBottomPage = CDCDocumentValue."Page No." then
                        if (CDCDocumentValue.Bottom > CurrLineBottomPos) or (CurrLineBottomPos = 0) then
                            CurrLineBottomPos := CDCDocumentValue.Bottom;
                end;
            until CDCDocumentValue.Next() = 0;

    end;

    local procedure GetStartAndEndCaption(var CaptionStartCDCDocumentWord: array[100] of Record "CDC Document Word" temporary; var CaptionEndCDCDocumentWord: array[100] of Record "CDC Document Word" temporary; CDCTemplateField: Record "CDC Template Field"; DocNo: Code[20]; PageNo: Integer): Boolean
    var
        CDCTemplateFieldCaption: Record "CDC Template Field Caption";
        CDCCaptureEngine: Codeunit "CDC Capture Engine";
    begin
        Clear(CaptionStartCDCDocumentWord);
        Clear(CaptionEndCDCDocumentWord);

        CDCTemplateFieldCaption.SetRange("Template No.", CDCTemplateField."Template No.");
        CDCTemplateFieldCaption.SetRange(Type, CDCTemplateField.Type);
        CDCTemplateFieldCaption.SetRange(Code, CDCTemplateField.Code);
        if CDCTemplateFieldCaption.FindSet() then
            repeat
                if CDCCaptureEngine.FindCaption(DocNo, PageNo, CDCTemplateField, CDCTemplateFieldCaption, CaptionStartCDCDocumentWord, CaptionEndCDCDocumentWord) then
                    exit(true);
            until (CDCTemplateFieldCaption.Next() = 0) or ((CaptionStartCDCDocumentWord[1].Word <> '') and (CaptionEndCDCDocumentWord[1].Word <> ''));
    end;

    local procedure GetPositionOfCaption(CurrCDCDocumentPage: Record "CDC Document Page"; CaptionCDCTemplateField: Record "CDC Template Field"; CaptionStartCDCDocumentWord: Record "CDC Document Word"; CaptionEndCDCDocumentWord: Record "CDC Document Word"; CDCDocumentValue: Record "CDC Document Value"; var FieldLeft: Integer; var FieldWidth: Integer; var Bottom: Integer; var Top: Integer) CaptionValueFound: Boolean
    var
        CDCCaptureEngine: Codeunit "CDC Capture Engine";
    begin
        CDCTemplate.Get(CaptionCDCTemplateField."Template No.");

        //Hole Positionen der caption
        CaptionValueFound := CDCCaptureManagement.CaptureFromPos(CurrCDCDocumentPage, CaptionCDCTemplateField, 0, false, CaptionStartCDCDocumentWord.Top, CaptionStartCDCDocumentWord.Left,
          CaptionEndCDCDocumentWord.Bottom, CaptionEndCDCDocumentWord.Right, CDCDocumentValue) <> '';

        if CaptionValueFound then begin
            FieldLeft := CaptionStartCDCDocumentWord.Left +
            Round(CaptionCDCTemplateField."Caption Offset X" * CDCCaptureEngine.GetDPIFactor(CaptionCDCTemplateField."Offset DPI", CurrCDCDocumentPage."TIFF Image Resolution"), 1);

            if not CDCTemplate."First Table Line Has Captions" then
                Bottom := CaptionStartCDCDocumentWord.Top
            else
                if CaptionStartCDCDocumentWord.Bottom > Bottom then
                    Bottom := CaptionStartCDCDocumentWord.Bottom;

            if FieldWidth < CaptionEndCDCDocumentWord.Right - CaptionStartCDCDocumentWord.Left then
                FieldWidth := CaptionEndCDCDocumentWord.Right - CaptionStartCDCDocumentWord.Left;

            Top := CaptionStartCDCDocumentWord.Top;
        end;
    end;

    local procedure CaptureTableCell(var CDCTemplateParam: Record "CDC Template"; var CDCDocumentPage: Record "CDC Document Page"; var CDCTemplateField: Record "CDC Template Field"; LineNo: Integer; Top: Integer; Left: Integer; Bottom: Integer; Right: Integer): Integer
    var
        CDCDocumentValue: Record "CDC Document Value";
    begin
        if (Right - Left <= 0) or (Bottom - Top <= 0) then
            exit;

        CDCCaptureManagement.CaptureFromPos(CDCDocumentPage, CDCTemplateField, LineNo, true, Top, Left, Bottom, Right, CDCDocumentValue);
        CDCDocumentValue.Find('=');

        if (CDCDocumentValue.IsBlank()) or TableCellAlreadyCaptured(CDCTemplateParam, CDCDocumentPage, CDCDocumentValue) then
            CDCDocumentValue.Delete()
        else
            exit(CDCDocumentValue.Bottom);
    end;

    local procedure TableCellAlreadyCaptured(var CDCTemplateParam: Record "CDC Template"; var CDCDocumentPage: Record "CDC Document Page"; var CDCDocumentValue: Record "CDC Document Value"): Boolean
    var
        CDCDocumentValue2: Record "CDC Document Value";
        CDCCaptureEngine: Codeunit "CDC Capture Engine";
    begin
        CDCDocumentValue2.SetCurrentKey("Document No.", "Is Value", Type, "Page No.");
        if not CDCTemplateParam."First Table Line Has Captions" then
            CDCDocumentValue2.SetRange("Is Value", true);
        CDCDocumentValue2.SetRange("Document No.", CDCDocumentPage."Document No.");
        CDCDocumentValue2.SetRange(Type, CDCDocumentValue2.Type::Line);
        CDCDocumentValue2.SetRange("Page No.", CDCDocumentValue."Page No.");

        CDCDocumentValue.Top := CDCDocumentValue.Top + Round((CDCDocumentValue.Bottom - CDCDocumentValue.Top) / 2, 1);
        CDCDocumentValue.Left := CDCDocumentValue.Left + 3;

        if CDCDocumentValue2.FindSet(false, false) then
            repeat
                if (not ((CDCDocumentValue2.Code = CDCDocumentValue.Code) and (CDCDocumentValue2."Line No." = CDCDocumentValue."Line No."))) then
                    if CDCCaptureEngine.IntersectsWith(CDCDocumentValue, CDCDocumentValue2) then
                        exit(true);
            until CDCDocumentValue2.Next() = 0;
    end;

    local procedure IsFieldValid(var CaptionCDCTemplateField: Record "CDC Template Field"; CDCDocument: Record "CDC Document"; LineNo: Integer): Boolean
    var
        CDCDocumentValue: Record "CDC Document Value";
        CDCTemplateField: Record "CDC Template Field";
    begin
        case CaptionCDCTemplateField."Data Type" of
            CDCTemplateField."Data Type"::Number:
                if (not CaptionCDCTemplateField.Required) then
                    if CDCDocumentValue.Get(CDCDocument."No.", true, CaptionCDCTemplateField.Code, LineNo) then
                        if not CDCDocumentValue."Is Valid" then
                            exit
                        else
                            exit(CDCCaptureManagement.ParseNumber(CDCTemplateField, CDCDocumentValue."Value (Text)", CDCDocumentValue."Value (Decimal)"));
            CDCTemplateField."Data Type"::Text:
                if CDCDocumentValue.Get(CDCDocument."No.", true, CaptionCDCTemplateField.Code, LineNo) then
                    exit(IsValidText(CaptionCDCTemplateField, CDCDocumentValue."Value (Text)", CDCDocument."No."));
            CDCTemplateField."Data Type"::Date:
                if CDCDocumentValue.Get(CDCDocument."No.", true, CaptionCDCTemplateField.Code, LineNo) then
                    exit(IsValidDate(CaptionCDCTemplateField, CDCDocumentValue."Value (Date)"));
            CDCTemplateField."Data Type"::Lookup:
                if CDCDocumentValue.Get(CDCDocument."No.", true, CaptionCDCTemplateField.Code, LineNo) then
                    exit(IsValidLookup(CaptionCDCTemplateField, CDCDocumentValue."Value (Text)", CDCDocument."No."));
        end;
        exit(true);
    end;

    local procedure FillSortedFieldBuffer(var TempSortedCDCTempDocumentField: Record "CDC Temp. Document Field"; var MandatoryCDCTempDocumentField: Record "CDC Temp. Document Field"; CDCTempDocumentLine: Record "CDC Temp. Document Line" temporary)
    var
        CDCTemplateField: Record "CDC Template Field";
    begin
        CDCTemplateField.SetRange(CDCTemplateField."Template No.", CDCTempDocumentLine."Template No.");
        CDCTemplateField.SetRange(CDCTemplateField.Type, CDCTemplateField.Type::Line);
        if CDCTemplateField.FindSet() then
            repeat
                if (CDCTemplateField."Advanced Line Recognition Type" <> CDCTemplateField."Advanced Line Recognition Type"::Default) and
                   (StrLen(CDCTemplateField.Formula) = 0) and (StrLen(CDCTemplateField.GetFixedValue()) = 0) then begin
                    TempSortedCDCTempDocumentField."Document No." := CDCTempDocumentLine."Document No.";
                    TempSortedCDCTempDocumentField."Sort Order" := CDCTemplateField.Sorting;
                    TempSortedCDCTempDocumentField."Field Code" := CDCTemplateField.Code;
                    TempSortedCDCTempDocumentField.Insert();
                end else
                    if CDCTemplateField.Required then begin
                        MandatoryCDCTempDocumentField."Document No." := CDCTempDocumentLine."Document No.";
                        MandatoryCDCTempDocumentField."Sort Order" := CDCTemplateField.Sorting;
                        MandatoryCDCTempDocumentField."Field Code" := CDCTemplateField.Code;
                        MandatoryCDCTempDocumentField.Insert();
                    end;
            until CDCTemplateField.Next() = 0;

    end;

    local procedure GetStopLineRecognitionPositions(var StopPos: array[100] of Integer; CurrPageNo: Integer; CDCDocument: Record "CDC Document")
    var
        CDCDocumentValue: Record "CDC Document Value";
        CDCTemplateField: Record "CDC Template Field";
    begin
        CDCTemplateField.Reset();
        CDCTemplateField.SetCurrentKey("Template No.", Type, "Sort Order");
        CDCTemplateField.SetRange("Template No.", CDCDocument."Template No.");
        CDCTemplateField.SetRange(Type, CDCTemplateField.Type::Header);
        CDCTemplateField.SetFilter("Stop Lines Recognition", '>%1', CDCTemplateField."Stop Lines Recognition"::" ");
        if CDCTemplateField.Find() then
            repeat
                CDCDocumentValue.Reset();
                CDCDocumentValue.SetRange("Document No.", CDCDocument."No.");
                CDCDocumentValue.SetRange(Type, CDCTemplateField.Type);
                CDCDocumentValue.SetRange(Code, CDCTemplateField.Code);
                CDCDocumentValue.SetRange("Page No.", CurrPageNo);

                case CDCTemplateField."Stop Lines Recognition" of
                    CDCTemplateField."Stop Lines Recognition"::"If Caption is on same line",
                  CDCTemplateField."Stop Lines Recognition"::"If Caption is on same line (continue on next page)":
                        CDCDocumentValue.SetRange("Is Value", false);
                    CDCTemplateField."Stop Lines Recognition"::"If Value is on same line",
                  CDCTemplateField."Stop Lines Recognition"::"If Value is on same line (continue on next page)":
                        CDCDocumentValue.SetRange("Is Value", true);
                    CDCTemplateField."Stop Lines Recognition"::"If Caption or Value is on same line",
                  CDCTemplateField."Stop Lines Recognition"::"If Caption or Value is on same line (continue on next page)":
                        CDCDocumentValue.SetRange("Is Value");
                end;

                CDCDocumentValue.SetFilter(Top, '>%1', 0);
                if CDCDocumentValue.FindFirst() then
                    if (StopPos[CDCDocumentValue."Page No."] = 0) or (StopPos[CDCDocumentValue."Page No."] > CDCDocumentValue.Top) then
                        if (not (CDCDocumentValue.Left = CDCDocumentValue.Right) and (CDCDocumentValue.Bottom = CDCDocumentValue.Top)) then
                            StopPos[CDCDocumentValue."Page No."] := CDCDocumentValue.Top;
            until CDCTemplateField.Next() = 0;
    end;

    internal procedure CleanupPrevValues(CDCDocument: Record "CDC Document")
    var
        CDCDocumentValue: Record "CDC Document Value";
    begin
        CDCDocumentValue.SetRange("Document No.", CDCDocument."No.");
        CDCDocumentValue.SetRange(Type, CDCDocumentValue.Type::Line);
        CDCDocumentValue.DeleteAll();
        ;
    end;

    local procedure CleanupTempValues(CDCDocument: Record "CDC Document")
    var
        CDCDocumentValue: Record "CDC Document Value";
    begin
        // Clean up temporary created values
        CDCDocumentValue.SetRange("Document No.", CDCDocument."No.");
        CDCDocumentValue.SetRange(Type, CDCDocumentValue.Type::Line);
        CDCDocumentValue.SetFilter("Line No.", '1000..');
        CDCDocumentValue.DeleteAll();
        ;
    end;

    // The following functions are a copy of the same functions in the Capture Management Codeunit, where they are defined as "local"

    local procedure IsValidDate(var CDCTemplateField: Record "CDC Template Field"; Date: Date): Boolean
    var
        CDCTemplateFieldRule: Record "CDC Template Field Rule";
    begin
        if CDCTemplateField."Codeunit ID: Capture Value" <> 0 then
            exit(TestCaptureValue(CDCTemplateField, CDCTemplateFieldRule, Format(Date)));

        if (Date = 0D) then
            exit(not CDCTemplateField.Required);

        if Format(CDCTemplateField."Validation Dateformula From") <> '' then
            if Date < CalcDate(CDCTemplateField."Validation Dateformula From", Today) then
                exit(false);

        if Format(CDCTemplateField."Validation Dateformula To") <> '' then
            if Date > CalcDate(CDCTemplateField."Validation Dateformula To", Today) then
                exit(false);

        if Date < 17540101D then
            exit(false);

        exit(true);
    end;

    local procedure IsValidText(var CDCTemplateField: Record "CDC Template Field"; Text: Text[250]; DocumentNo: Code[20]): Boolean
    var
        TempCDCDocumentValue: Record "CDC Document Value" temporary;
        CDCTemplateFieldRule: Record "CDC Template Field Rule";
        CDCRegExManagement: Codeunit "CDC RegEx Management";
        IsValid: Boolean;
    begin
        Text := UpperCase(Text);

        if CDCTemplateField."Codeunit ID: Capture Value" <> 0 then
            if TestCaptureValue(CDCTemplateField, CDCTemplateFieldRule, Text) then
                exit(true);

        CDCCaptureManagement.FilterRule(CDCTemplateField, CDCTemplateFieldRule);
        if not CDCTemplateFieldRule.FindFirst() then
            exit((Text <> '') or (not CDCTemplateField.Required));

        if Text = '' then
            exit(not CDCTemplateField.Required);

        TempCDCDocumentValue."Value (Text)" := Text;
        TempCDCDocumentValue.Insert();

        repeat
            CDCTemplateFieldRule.Rule := UpperCase(CDCTemplateFieldRule.Rule);
            if (StrPos(CDCTemplateFieldRule.Rule, '<') <> 0) or
              (StrPos(CDCTemplateFieldRule.Rule, '>') <> 0) or
              (StrPos(CDCTemplateFieldRule.Rule, '|') <> 0) or
              (StrPos(CDCTemplateFieldRule.Rule, '*') <> 0) or
              (StrPos(CDCTemplateFieldRule.Rule, '&') <> 0)
            then begin
                TempCDCDocumentValue.SetFilter("Value (Text)", CDCTemplateFieldRule.Rule);
                IsValid := not TempCDCDocumentValue.IsEmpty;
            end else begin
                if CDCRegExManagement.IsMatch(Text, CDCTemplateFieldRule.Rule) then
                    if CDCTemplateField."Codeunit ID: Capture Value" <> 0 then
                        IsValid := TestCaptureValue(CDCTemplateField, CDCTemplateFieldRule, Text)
                    else
                        IsValid := true;

                if IsValid and CDCTemplateField."Enable Rule Generation" then begin
                    ClearFldRuleCreatedFromMaster(CDCTemplateFieldRule, DocumentNo);

                    // Several rules could have been copied from the master template. Delete these when a rule matches the found value
                    DelFldRulesCreatedFromMaster(CDCTemplateFieldRule."Entry No.");
                end;
            end;
        until (CDCTemplateFieldRule.Next() = 0) or (IsValid);

        exit(IsValid);
    end;

    local procedure IsValidLookup(CDCTemplateField: Record "CDC Template Field"; CDCDocumentValue: Text[250]; DocumentNo: Code[20]): Boolean
    begin
        exit(IsValidText(CDCTemplateField, CDCDocumentValue, DocumentNo));
    end;

    // local procedure IsValidBoolean(var CDCTemplateField: Record "CDC Template Field"; Boolean: Boolean): Boolean
    // begin
    //     exit(true);
    // end;

    local procedure TestCaptureValue(CDCTemplateField: Record "CDC Template Field"; CDCTemplateFieldRule: Record "CDC Template Field Rule"; CDCDocumentValue: Text[1024]): Boolean
    var
        CDCTempCaptureFieldValid: Record "CDC Temp. Capture Field Valid.";
    begin
        CDCTempCaptureFieldValid."Field Type" := CDCTemplateField.Type;
        CDCTempCaptureFieldValid."Field Code" := CDCTemplateField.Code;
        CDCTempCaptureFieldValid."File Rule Entry No." := CDCTemplateFieldRule."Entry No.";
        CDCTempCaptureFieldValid.Rule := CDCTemplateFieldRule.Rule;
        CDCTempCaptureFieldValid.Value := CopyStr(CDCDocumentValue, 1, MaxStrLen(CDCTempCaptureFieldValid.Value));
        CODEUNIT.Run(CDCTemplateField."Codeunit ID: Capture Value", CDCTempCaptureFieldValid);
        exit(CDCTempCaptureFieldValid."Is Valid");
    end;

    local procedure ClearFldRuleCreatedFromMaster(var CDCTemplateFieldRule: Record "CDC Template Field Rule"; DocumentNo: Code[20])
    begin
        if CDCTemplateFieldRule."Created from Master Template" then begin
            CDCTemplateFieldRule."Created from Master Template" := false;
            CDCTemplateFieldRule."Document No." := DocumentNo;
            CDCTemplateFieldRule.Modify(true);
        end;
    end;

    local procedure DelFldRulesCreatedFromMaster(SkipEntryNo: Integer)
    var
        CDCTemplateFieldRule: Record "CDC Template Field Rule";
    begin
        CDCTemplateFieldRule.SetRange("Created from Master Template", true);
        CDCTemplateFieldRule.SetFilter("Entry No.", '<>%1', SkipEntryNo);
        if not CDCTemplateFieldRule.IsEmpty then
            CDCTemplateFieldRule.DeleteAll(true);
    end;


    [IntegrationEvent(TRUE, false)]
    local procedure OnAfterStandardLineRecognition(var CDCDocument: Record "CDC Document"; var Handled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeLineFinalProcessing(CDCDocument: Record "CDC Document"; var CDCTempDocumentLine: Record "CDC Temp. Document Line" temporary; Handled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterLineFinalProcessing(CDCDocument: Record "CDC Document"; var CDCTempDocumentLine: Record "CDC Temp. Document Line" temporary)
    begin
    end;
}

