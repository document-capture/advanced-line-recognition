#pragma warning disable AA0072
codeunit 61001 "ALR Advanced Line Capture"
{
    TableNo = "CDC Document";

    var
#pragma warning disable AA0237
        TempMandatoryField: Record "CDC Temp. Document Field" temporary;
        CDCTemplate: Record "CDC Template";
        CaptureMgt: Codeunit "CDC Capture Management";
        LineManagementSI: Codeunit "ALR Single Instance Mgt.";
        NoMandatoryFieldsFoundLbl: Label 'You cannot use the advanced line recognition option %1 when the template does not have at least one line field marked as required!', Comment = 'Show when the template does not have at least one line field marked as required. %1 = selected ALR option', MaxLength = 999, Locked = false;
#pragma warning restore AA0237
    trigger OnRun()
    begin
        //Reset template to standard line capture as we can now use an event
        if not CDCTemplate.Get(Rec."Template No.") then
            exit;

        CDCTemplate."Codeunit ID: Line Capture" := 6085716;
        CDCTemplate.Modify(true);

        Codeunit.Run(CDCTemplate."Codeunit ID: Line Capture", Rec);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CDC Purch. - Full Capture", 'OnAfterFullCapture', '', true, true)]
    local procedure CDCPurchFullCapture_OnAfterFullCapture(Document: Record "CDC Document")
    begin
        FindAllPONumbersInDocument(Document);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CDC Capture Engine", 'OnBeforeRunLineCaptureCodeunit', '', true, true)]
    local procedure CDCCaptureEngine_OnBeforeRunLineCaptureCodeunit(Document: Record "CDC Document"; var Handled: Boolean)
    var
        TempDocLine: Record "CDC Temp. Document Line" temporary;
        CDCTemplateField: Record "CDC Template Field";
        TempSortedDocumentField: Record "CDC Temp. Document Field" temporary;
    begin
        CleanupPrevValues(Document);
        if not CDCTemplate.Get(Document."Template No.") then
            exit;

        //RUN STANDARD LINE CAPTURING CODEUNIT
        if (CDCTemplate."Codeunit ID: Line Capture" <> 0) then
            Codeunit.Run(CDCTemplate."Codeunit ID: Line Capture", Document);

        OnAfterStandardLineRecognition(Document, Handled);
        if Handled then
            exit;

        //BUILD TEMPORARY LINE TABLE AND LOOP LINES
        Document.BuildTempLinesTable(TempDocLine);

        if TempDocLine.FindSet() then begin
            FillSortedFieldBuffer(TempSortedDocumentField, TempMandatoryField, TempDocLine);
            repeat
                TempSortedDocumentField.SetCurrentKey("Document No.", "Sort Order");
                if TempSortedDocumentField.FindSet() then
                    repeat
                        CDCTemplateField.Get(TempDocLine."Template No.", CDCTemplateField.Type::Line, TempSortedDocumentField."Field Code");
                        case CDCTemplateField."Advanced Line Recognition Type" of
                            CDCTemplateField."Advanced Line Recognition Type"::LinkedToAnchorField:
                                FindValueFromOffsetField(TempDocLine, CDCTemplateField);
                            CDCTemplateField."Advanced Line Recognition Type"::FindFieldByCaptionInPosition:
                                FindValueByCaptionInPosition(TempDocLine, CDCTemplateField, Document);
                            CDCTemplateField."Advanced Line Recognition Type"::FindFieldByColumnHeading:
                                FindFieldByColumnHeading(TempDocLine, CDCTemplateField, Document);
                        end;
                    until TempSortedDocumentField.Next() = 0;

                FindReplacementFieldValue(TempDocLine);

                GetValueFromPreviousValue(TempDocLine);
            until TempDocLine.Next() = 0;
            CleanupTempValues(Document);
        end;

        Handled := true;
    end;

    local procedure FindValueFromOffsetField(TempDocLine: Record "CDC Temp. Document Line" temporary; var OffsetField: Record "CDC Template Field")
    var
        OffsetSourceField: Record "CDC Template Field";
        OffsetSourceFieldValue: Record "CDC Document Value";
        DocumentValue: Record "CDC Document Value";
        CurrPage: Record "CDC Document Page";
        CurrTop: Integer;
        CurrLeft: Integer;
        CurrBottom: Integer;
        CurrRight: Integer;
    begin
        //This function will capture the field value based on the offset/distance of a source field value

        //Get Line Identification Field Position
        if not OffsetSourceField.Get(TempDocLine."Template No.", OffsetSourceField.Type::Line, OffsetField."Linked Field") then
            exit;

        // Get current value record of offset source field
        if not OffsetSourceFieldValue.Get(TempDocLine."Document No.", true, OffsetSourceField.Code, TempDocLine."Line No.") then
            exit;

        CurrPage.Get(TempDocLine."Document No.", OffsetSourceFieldValue."Page No.");

        // Create offset area for value capturing
        CurrTop := OffsetSourceFieldValue.Top + OffsetField."Offset Top";
        CurrLeft := OffsetSourceFieldValue.Left + OffsetField."Offset Left";
        CurrBottom := CurrTop + OffsetField."Offset Bottom";
        CurrRight := CurrLeft + OffsetField."Offset Right";
        CaptureMgt.CaptureFromPos(CurrPage, OffsetField, TempDocLine."Line No.", true, CurrTop, CurrLeft, CurrBottom, CurrRight, DocumentValue);
        if DocumentValue.Get(TempDocLine."Document No.", true, OffsetField.Code, TempDocLine."Line No.") then
            if ((DocumentValue."Value (Text)" = '') and (DocumentValue."Value (Decimal)" = 0)) or (not DocumentValue."Is Valid") then
                DocumentValue.Delete();

    end;

    local procedure FindValueByCaptionInPosition(var TempDocLine: Record "CDC Temp. Document Line" temporary; var CurrField: Record "CDC Template Field"; Document: Record "CDC Document"): Boolean
    var
        DocumentValue: Record "CDC Document Value";
        DocumentValueCopy: Record "CDC Document Value";
        CurrPage: Record "CDC Document Page";
        CaptureEngine: Codeunit "CDC Capture Engine";
        Word: Text[1024];
        FromTopPos: Integer;
        FromTopPage: Integer;
        ToBottomPos: Integer;
        ToBottomPage: Integer;
        i: Integer;
    begin
        // We cannot proceed if there is no line field in the template defined as required=true
        if TempMandatoryField.Count = 0 then
            error(NoMandatoryFieldsFoundLbl, CurrField."Advanced Line Recognition Type");

        //This function will capture the field value based on the caption(s) in the area between the previous and next
        if not Document.Get(TempDocLine."Document No.") then
            exit;

        //Delete current value
        if DocumentValue.Get(TempDocLine."Document No.", true, CurrField.Code, TempDocLine."Line No.") then
            DocumentValue.Delete();

        Clear(Word);

        // Get valid range depended of search direction
        // 1. above the standard recognized line: range is between standard standard line and previous line
        // 2. below the standard recognized line: range is between standard standard line and next line
        if (CurrField."Field value position" = CurrField."Field value position"::AboveStandardLine) then
            GetRangeToPrevLine(Document, TempDocLine, FromTopPage, FromTopPos, ToBottomPage, ToBottomPos)
        else
            GetRangeToNextLine(Document, TempDocLine, FromTopPage, FromTopPos, ToBottomPage, ToBottomPos);

        if (FromTopPage > 0) and (ToBottomPage > 0) then   //there are some situations where the system couldn't find the range
            for i := FromTopPage to ToBottomPage do begin
                if not CurrPage.Get(TempDocLine."Document No.", i) then
                    exit;

                CurrField."Caption Offset X" := CurrField."ALR Value Caption Offset X";
                CurrField."Caption Offset Y" := CurrField."ALR Value Caption Offset Y";
                CurrField."Typical Field Width" := CurrField."ALR Typical Value Field Width";

                // set the line region
                if i < ToBottomPage then
                    LineManagementSI.SetLineRegion(TempDocLine."Document No.", i, FromTopPos, i, CurrPage."Bottom Word Pos.")
                else
                    if (i > FromTopPage) and (i < ToBottomPage) then
                        LineManagementSI.SetLineRegion(TempDocLine."Document No.", i, 0, i, CurrPage."Bottom Word Pos.")
                    else
                        if FromTopPos > ToBottomPos then
                            LineManagementSI.SetLineRegion(TempDocLine."Document No.", i, 0, i, ToBottomPos)
                        else
                            LineManagementSI.SetLineRegion(TempDocLine."Document No.", i, FromTopPos, i, ToBottomPos);

                // Find value in predefined line region
                Word := CaptureEngine.CaptureField(Document, CurrPage."Page No.", CurrField, false);

                if Word <> '' then begin
                    if (DocumentValue.Get(Document."No.", true, CurrField.Code, 0)) then begin
                        DocumentValueCopy := DocumentValue;
                        DocumentValueCopy."Line No." := TempDocLine."Line No.";
                        DocumentValueCopy.Type := DocumentValueCopy.Type::Line;
                        DocumentValueCopy.Insert();
                        DocumentValue.Delete();
                    end;
                    CaptureMgt.UpdateFieldValue(Document."No.", TempDocLine."Page No.", TempDocLine."Line No.", CurrField, Word, false, false);

                    exit(true);
                end;
            end;




    end;

    local procedure FindFieldByColumnHeading(var TempDocLine: Record "CDC Temp. Document Line" temporary; var CurrField: Record "CDC Template Field"; Document: Record "CDC Document")
    var
        DocumentValue: Record "CDC Document Value";
        TempDocumentValue: Record "CDC Document Value" temporary;
        DocumentValueNew: Record "CDC Document Value";
        CaptionStartWord: array[100] of Record "CDC Document Word";
        CaptionEndWord: array[100] of Record "CDC Document Word";
        CaptionPage: Record "CDC Document Page";
        CurrPage: Record "CDC Document Page";
        CaptionValue: Record "CDC Document Value";
        CaptionPageNo: Integer;
        CaptionFound: Boolean;
        PageStop: Boolean;
        FromTopPos: Integer;
        FromTopPage: Integer;
        ToBottomPos: Integer;
        ToBottomPage: Integer;
        NewBottom: Integer;
        LineNo: Integer;
        LineHeight: Integer;
        Top: Integer;
        Bottom: Integer;
        Right: Integer;
        FieldLeft: Integer;
        FieldWidth: Integer;
        LastFoundLineNo: Integer;
    begin
        // We cannot proceed if there is no line field in the template defined as required=true
        if TempMandatoryField.Count = 0 then
            error(NoMandatoryFieldsFoundLbl, CurrField."Advanced Line Recognition Type");

        //This function will capture the field value based on a column heading, actualy like the default line recognition but filtered on the area between the prev. and next line
        if not Document.Get(TempDocLine."Document No.") then
            exit;

        if not CDCTemplate.Get(TempDocLine."Template No.") then
            exit;

        // Delete old values
        if DocumentValue.Get(TempDocLine."Document No.", true, CurrField.Code, TempDocLine."Line No.") then
            DocumentValue.Delete();

        // Find the Caption position on current or previous pages
        CaptionPageNo := TempDocLine."Page No.";
        repeat
            CaptionFound := GetStartAndEndCaption(CaptionStartWord, CaptionEndWord, CurrField, TempDocLine."Document No.", CaptionPageNo);
            if not CaptionFound then
                CaptionPageNo -= 1;
        until (CaptionPageNo = 0) or CaptionFound;

        if (not CaptionFound) then
            exit;

        if not CaptionPage.Get(TempDocLine."Document No.", CaptionPageNo) then
            exit;

        GetPositionOfCaption(CaptionPage, CurrField, CaptionStartWord[1], CaptionEndWord[1], CaptionValue, FieldLeft, FieldWidth, Bottom, Top);

        // Get position of next or previous line
        if (CurrField."Field value position" = CurrField."Field value position"::AboveStandardLine) then begin
            GetRangeToPrevLine(Document, TempDocLine, FromTopPage, FromTopPos, ToBottomPage, ToBottomPos);
            if FromTopPos > Top then
                Top := FromTopPos;
        end else begin
            GetRangeToNextLine(Document, TempDocLine, FromTopPage, FromTopPos, ToBottomPage, ToBottomPos);
            Top := FromTopPos;
        end;

        NewBottom := 0;
        LineNo := 1000 * TempDocLine."Page No.";
        LineHeight := 12;


        Bottom := Top + LineHeight;

        PageStop := false;
        if not CurrPage.Get(TempDocLine."Document No.", FromTopPage) then
            exit;
        repeat
            LineNo += 1;
            Right := FieldLeft + FieldWidth;
            NewBottom := CaptureTableCell(CDCTemplate, CurrPage, CurrField, LineNo, Top, FieldLeft, Bottom, Right);
            if NewBottom > 0 then begin
                if NewBottom > Bottom then
                    Bottom := NewBottom;

                if not IsFieldValid(CurrField, Document, LineNo) then begin
                    DocumentValue.Reset();
                    ;
                    DocumentValue.SetRange("Document No.", Document."No.");
                    DocumentValue.SetRange("Line No.", LineNo);
                    DocumentValue.DeleteAll(true);
                end else begin

                    LastFoundLineNo := LineNo;
                    // Stop search, when search direction is upwards from standard line
                    PageStop := (CurrField."Field value search direction" = CurrField."Field value search direction"::Downwards);
                    if DocumentValue.Get(TempDocLine."Document No.", true, CurrField.Code, LastFoundLineNo) then begin
                        TempDocumentValue := DocumentValue;
                        TempDocumentValue.Insert();
                        DocumentValue.Delete();
                    end;
                end;
            end;

            if not PageStop then begin
                Top := Bottom;
                Bottom := Top + LineHeight;

                if (Bottom > CurrPage."Bottom Word Pos.") and (CurrPage."Page No." < ToBottomPage) then begin
                    //New page - some variables must be reset
                    CurrPage.Get(CurrPage."Document No.", CurrPage."Page No." + 1);
                    CaptionPageNo := CurrPage."Page No.";
                    LineNo := 1000 * CurrPage."Page No.";
                    if GetStartAndEndCaption(CaptionStartWord, CaptionEndWord, CurrField, TempDocLine."Document No.", CaptionPageNo) then begin
                        CaptionPage.Get(TempDocLine."Document No.", CurrPage."Page No.");
                        if GetPositionOfCaption(CaptionPage, CurrField, CaptionStartWord[1], CaptionEndWord[1], CaptionValue, FieldLeft, FieldWidth, Bottom, Top) then
                            Bottom := Top + LineHeight;

                    end;
                end else
                    if (Bottom > CurrPage."Bottom Word Pos.") or ((Bottom > ToBottomPos) and (CurrPage."Page No." = ToBottomPage)) then
                        PageStop := true;
            end;
        until PageStop;

        //Zeilennr. speichern
        if TempDocumentValue.Get(TempDocLine."Document No.", true, CurrField.Code, LastFoundLineNo) then begin
            DocumentValueNew := TempDocumentValue;
            DocumentValueNew."Line No." := TempDocLine."Line No.";
            DocumentValueNew.Insert();
            TempDocumentValue.Delete();
            CaptureMgt.UpdateFieldValue(TempDocLine."Document No.", TempDocLine."Page No.", TempDocLine."Line No.", CurrField, DocumentValueNew."Value (Text)", false, false);
        end;
    end;

    local procedure FindReplacementFieldValue(var TempDocLine: Record "CDC Temp. Document Line" temporary)
    var
        CDCTemplateField: Record "CDC Template Field";
        DocumentValue: Record "CDC Document Value";
        SubstitutionDocumentValue: Record "CDC Document Value";
        SubstitutionField: Record "CDC Template Field";
        TempLineNo: Integer;
    begin
        // Function goes through all field, setted up with substitution fields.
        // It checks if the value of the current field is empty and updates the value with the value of the substitution field (if exists).
        CDCTemplateField.SetRange("Template No.", TempDocLine."Template No.");
        CDCTemplateField.SetRange(Type, CDCTemplateField.Type::Line);
#pragma warning disable AA0210
        CDCTemplateField.SetFilter("Replacement Field", '<>%1', '');
#pragma warning restore AA0210
        if CDCTemplateField.IsEmpty then
            exit;

        CDCTemplateField.FindSet();
        repeat
            if not DocumentValue.Get(TempDocLine."Document No.", true, CDCTemplateField.Code, TempDocLine."Line No.") then
                if SubstitutionField.Get(TempDocLine."Template No.", CDCTemplateField."Replacement Field Type", CDCTemplateField."Replacement Field") then begin
                    // Header fields have line no = 0
                    if CDCTemplateField."Replacement Field Type" = CDCTemplateField."Replacement Field Type"::Header then
                        TempLineNo := 0
                    else
                        TempLineNo := TempDocLine."Line No.";

                    if SubstitutionDocumentValue.Get(TempDocLine."Document No.", true, SubstitutionField.Code, TempLineNo) then begin
                        CaptureMgt.UpdateFieldValue(TempDocLine."Document No.", TempDocLine."Page No.", TempDocLine."Line No.", CDCTemplateField, SubstitutionDocumentValue."Value (Text)", false, false);
                        if DocumentValue.Get(TempDocLine."Document No.", true, CDCTemplateField.Code, TempDocLine."Line No.") then begin
                            DocumentValue.Top := SubstitutionDocumentValue.Top;
                            DocumentValue.Bottom := SubstitutionDocumentValue.Bottom;
                            DocumentValue.Left := SubstitutionDocumentValue.Left;
                            DocumentValue.Right := SubstitutionDocumentValue.Right;
                            DocumentValue.Modify();
                        end;
                    end;
                end;
        until CDCTemplateField.Next() = 0;
    end;

    local procedure GetValueFromPreviousValue(var TempDocLine: Record "CDC Temp. Document Line" temporary)
    var
        CDCTemplateField: Record "CDC Template Field";
        DocumentValue: Record "CDC Document Value";
    begin
        // Function goes through all field, setted up with substitution fields.
        // It checks if the value of the current field is empty and updates the value with the value of the substitution field (if exists).
        CDCTemplateField.SetRange("Template No.", TempDocLine."Template No.");
        CDCTemplateField.SetRange("Copy Value from Previous Value", true);
        if CDCTemplateField.FindSet() then
            repeat
                if not DocumentValue.Get(TempDocLine."Document No.", true, CDCTemplateField.Code, TempDocLine."Line No.") then
                    if DocumentValue.Get(TempDocLine."Document No.", true, CDCTemplateField.Code, TempDocLine."Line No." - 1) then
                        CaptureMgt.UpdateFieldValue(TempDocLine."Document No.", TempDocLine."Page No.", TempDocLine."Line No.", CDCTemplateField, DocumentValue."Value (Text)", false, false);
            until CDCTemplateField.Next() = 0;
    end;

    local procedure FindAllPONumbersInDocument(var Document: Record "CDC Document")
    var
        DocumentWord: Record "CDC Document Word";
        DocumentValue: Record "CDC Document Value";
#pragma warning disable AA0237
        Template: Record "CDC Template";
        TemplateField: Record "CDC Template Field";
#pragma warning restore AA0237
        PurchaseHeader: Record "Purchase Header";
        TempPurchaseHeader: Record "Purchase Header" temporary;
        CDCModuleLicense: Codeunit "CDC Module License";
        FoundPurchaseOrders: text;
    begin
        if not CDCModuleLicense.IsMatchingActivated(TRUE) then
            exit;

        if not Template.GET(Document."Template No.") then
            exit;

        if ((NOT Template."Auto PO search") OR (StrLen(Template."Auto PO search filter") < 2)) then
            exit;

        // Get order no. field first.
        if not TemplateField.GET(Document."Template No.", TemplateField.Type::Header, 'OURDOCNO') then
            exit;

        DocumentWord.SETRANGE("Document No.", Document."No.");

        // Iterate through Document Word table and filter for our PO number filter string
        DocumentWord.SetFilter(Word, Template."Auto PO search filter");
        if DocumentWord.FindSet() then
            repeat
                // Check if there is a PO in the system with the matched word
                IF PurchaseHeader.GET(PurchaseHeader."Document Type"::Order, CopyStr(UPPERCASE(DocumentWord.Word), 1, MAXSTRLEN(PurchaseHeader."No."))) THEN
                    // Check if the number exists in the temp. PO buffer
                    if not TempPurchaseHeader.GET(PurchaseHeader."Document Type", PurchaseHeader."No.") then begin
                        TempPurchaseHeader := PurchaseHeader;
                        TempPurchaseHeader.Insert();
                    end;
            until DocumentWord.Next() = 0;

        // Iterate through all found PO's and create the string, that can be used for order matching
        if TempPurchaseHeader.FindSet() then
            repeat
                if (STRLEN(FoundPurchaseOrders) + STRLEN(TempPurchaseHeader."No.") + 1) <= MAXSTRLEN(DocumentValue."Value (Text)") then begin
                    if (STRLEN(FoundPurchaseOrders) > 0) then
                        FoundPurchaseOrders += ',';
                    FoundPurchaseOrders += TempPurchaseHeader."No.";
                END;
            until TempPurchaseHeader.Next() = 0;

        TemplateField.GET(Document."Template No.", TemplateField.Type::Header, 'OURDOCNO');
        CaptureMgt.UpdateFieldValue(Document."No.", 0, 0, TemplateField, FoundPurchaseOrders, FALSE, FALSE);
    end;

    local procedure GetRangeToNextLine(Document: Record "CDC Document"; var TempDocLine: Record "CDC Temp. Document Line"; var SearchFromPage: Integer; var SearchFromPos: Integer; var SearchToPage: Integer; var SearchToPos: Integer)
    var
        DocumentValue: Record "CDC Document Value";
        CurrPage: Record "CDC Document Page";
        StopPos: array[100] of Integer;
    begin
        // This function calculates the range until the next position/line
        Clear(SearchFromPage);
        Clear(SearchFromPos);
        Clear(SearchToPage);
        Clear(SearchToPos);

        DocumentValue.SetCurrentKey(DocumentValue."Document No.", DocumentValue."Is Value", DocumentValue.Code, DocumentValue."Line No.");
        DocumentValue.SetRange(DocumentValue."Document No.", Document."No.");
        DocumentValue.SetRange(DocumentValue."Is Value", true);
        DocumentValue.SetRange(DocumentValue.Type, DocumentValue.Type::Line);
        DocumentValue.SetFilter(DocumentValue."Page No.", '>%1', 0);

        GetCurrLinePosition(DocumentValue, TempDocLine."Line No.", SearchFromPage, SearchFromPos, SearchToPage, SearchToPos);
        // Filter for next line
        DocumentValue.SetRange(DocumentValue."Line No.", TempDocLine."Line No." + 1);
        if DocumentValue.FindSet() then
            repeat
                if (SearchToPage < DocumentValue."Page No.") or (SearchToPage = 0) then begin
                    SearchToPage := DocumentValue."Page No.";
                    SearchToPos := 0;
                end;

                if SearchToPage = DocumentValue."Page No." then
                    if (SearchToPos < DocumentValue.Bottom) or (SearchToPos = 0) then
                        SearchToPos := DocumentValue.Bottom;

            until DocumentValue.Next() = 0
        else begin
            // As there is no next line, calculate to next header value or bottom of current page
            DocumentValue.SetCurrentKey(DocumentValue."Document No.", DocumentValue."Is Value", DocumentValue.Code, DocumentValue."Line No.");
            DocumentValue.SetRange(DocumentValue."Document No.", Document."No.");
            DocumentValue.SetRange(DocumentValue."Is Value", false);
            DocumentValue.SetRange(DocumentValue.Type, DocumentValue.Type::Header);
            DocumentValue.SetRange(DocumentValue."Page No.", SearchToPage);
            DocumentValue.SetFilter(DocumentValue.Top, '>%1', SearchToPos);
            DocumentValue.SetRange(DocumentValue."Line No.", 0);
            if DocumentValue.FindSet(false, false) then begin
                if DocumentValue."Page No." > SearchToPage then
                    SearchToPage := DocumentValue."Page No.";

                SearchToPos := DocumentValue.Top
            end else begin
                DocumentValue.SetFilter(DocumentValue."Page No.", '>%1', SearchToPage);
                DocumentValue.SetRange(DocumentValue.Top);
                if DocumentValue.FindFirst() then begin
                    if DocumentValue."Page No." > SearchToPage then
                        SearchToPage := DocumentValue."Page No.";

                    SearchToPos := DocumentValue.Top
                end else begin
                    CurrPage.Get(Document."No.", SearchToPage);
                    SearchToPos := CurrPage."Bottom Word Pos.";
                end;
            end;


            GetStopLineRecognitionPositions(StopPos, SearchToPage, Document);
            if (StopPos[SearchToPage] > 0) and (StopPos[SearchToPage] <= SearchToPos) then
                SearchToPos := StopPos[SearchToPage];
        end;
    end;

    local procedure GetRangeToPrevLine(Document: Record "CDC Document"; var TempDocLine: Record "CDC Temp. Document Line"; var RangeTopPage: Integer; var RangeTopPos: Integer; var RangeBottomPage: Integer; var RangeBottomPos: Integer)
    var
        DocumentValue: Record "CDC Document Value";
        CurrLineTopPage: Integer;
        CurrLineTopPos: Integer;
        CurrLineBottomPage: Integer;
        CurrLineBottomPos: Integer;
        PrevLineTopPage: Integer;
        PrevLineTopPos: Integer;
        PrevLineBottomPage: Integer;
        PrevLineBottomPos: Integer;
    begin
        // This function calculates the range until the previous position/line
        Clear(PrevLineTopPage);
        Clear(PrevLineTopPos);
        Clear(PrevLineBottomPage);
        Clear(PrevLineBottomPos);

        DocumentValue.SetCurrentKey(DocumentValue."Document No.", DocumentValue."Is Value", DocumentValue.Code, DocumentValue."Line No.");
        DocumentValue.SetRange(DocumentValue."Document No.", Document."No.");
        DocumentValue.SetRange(DocumentValue."Is Value", true);
        DocumentValue.SetRange(DocumentValue.Type, DocumentValue.Type::Line);
        DocumentValue.SetFilter(DocumentValue."Page No.", '>%1', 0);

        GetCurrLinePosition(DocumentValue, TempDocLine."Line No.", CurrLineTopPage, CurrLineTopPos, CurrLineBottomPage, CurrLineBottomPos);
        // Filter for Prev line
        DocumentValue.SetRange(DocumentValue."Line No.", TempDocLine."Line No." - 1);
        if DocumentValue.FindSet() then
            repeat
                if (DocumentValue."Page No." < PrevLineTopPage) or (PrevLineTopPage = 0) then begin
                    PrevLineTopPage := DocumentValue."Page No.";
                    Clear(PrevLineTopPos);
                end;

                if (DocumentValue."Page No." > PrevLineBottomPage) or (PrevLineBottomPage = 0) then begin
                    PrevLineBottomPage := DocumentValue."Page No.";
                    Clear(PrevLineBottomPos);
                end;

                if PrevLineTopPage = DocumentValue."Page No." then
                    if (DocumentValue.Top < PrevLineTopPos) or (PrevLineTopPos = 0) then
                        PrevLineTopPos := DocumentValue.Top;

                if PrevLineBottomPage = DocumentValue."Page No." then
                    if (DocumentValue.Bottom > PrevLineBottomPos) or (PrevLineBottomPos = 0) then
                        PrevLineBottomPos := DocumentValue.Bottom;
            until DocumentValue.Next() = 0
        else begin
            // As there is no Prev line, calculate to Prev header value or bottom of current page
            DocumentValue.SetCurrentKey(DocumentValue."Document No.", DocumentValue."Is Value", DocumentValue.Code, DocumentValue."Line No.");
            DocumentValue.SetRange(DocumentValue."Document No.", Document."No.");
            DocumentValue.SetRange(DocumentValue."Is Value", false);
            DocumentValue.SetRange(DocumentValue.Type, DocumentValue.Type::Header);
            DocumentValue.SetFilter(DocumentValue."Page No.", '<=%1', DocumentValue."Page No.");
            DocumentValue.SetFilter(DocumentValue.Top, '<%1', CurrLineTopPos);
            if DocumentValue.FindFirst() then begin
                PrevLineBottomPos := DocumentValue.Bottom;
                PrevLineBottomPage := DocumentValue."Page No.";
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

    local procedure GetCurrLinePosition(var DocumentValue: Record "CDC Document Value"; LineNo: Integer; var CurrLineTopPage: Integer; var CurrLineTopPos: Integer; var CurrLineBottomPage: Integer; var CurrLineBottomPos: Integer)
    begin
        // Filter for current line
        DocumentValue.SetRange(DocumentValue."Line No.", LineNo);
        if DocumentValue.FindSet() then
            repeat
                if TempMandatoryField.Get(DocumentValue.GetFilter("Document No."), DocumentValue.Code) then begin
                    if (DocumentValue."Page No." < CurrLineTopPage) or (CurrLineTopPage = 0) then begin
                        CurrLineTopPage := DocumentValue."Page No.";
                        Clear(CurrLineTopPos);
                    end;

                    if (DocumentValue."Page No." > CurrLineBottomPage) or (CurrLineBottomPage = 0) then begin
                        CurrLineBottomPage := DocumentValue."Page No.";
                        Clear(CurrLineBottomPos);
                    end;

                    if CurrLineTopPage = DocumentValue."Page No." then
                        if (DocumentValue.Top < CurrLineTopPos) or (CurrLineTopPos = 0) then
                            CurrLineTopPos := DocumentValue.Top;

                    if CurrLineBottomPage = DocumentValue."Page No." then
                        if (DocumentValue.Bottom > CurrLineBottomPos) or (CurrLineBottomPos = 0) then
                            CurrLineBottomPos := DocumentValue.Bottom;
                end;
            until DocumentValue.Next() = 0;

    end;

    // local procedure GetLinePositions(DocumentNo: Code[20]; LineNo: Integer; var CurrLineTopPage: Integer; var CurrLineTopPos: Integer; var CurrLineBottomPage: Integer; var CurrLineBottomPos: Integer; IsValue: Boolean)
    // var
    //     DocumentValue: Record "CDC Document Value";
    // begin
    //     //Find next lines top position
    //     DocumentValue.SetCurrentKey("Document No.", "Is Value", Code, "Line No.");
    //     DocumentValue.SetRange("Document No.", DocumentNo);
    //     DocumentValue.SetRange("Is Value", IsValue);
    //     DocumentValue.SetRange(Type, DocumentValue.Type::Line);
    //     if not IsValue then begin
    //         DocumentValue.SetRange("Line No.", 0);
    //         DocumentValue.SetRange("Page No.", 1);
    //     end else
    //         DocumentValue.SetRange("Line No.", LineNo);

    //     DocumentValue.SetFilter(Top, '>0');

    //     // Identify current lines outer positions
    //     if DocumentValue.FindSet() then
    //         repeat
    //             if (CurrLineTopPage > DocumentValue."Page No.") or (CurrLineTopPage = 0) then
    //                 CurrLineTopPage := DocumentValue."Page No.";
    //             Clear(CurrLineTopPos);

    //             if (CurrLineBottomPage < DocumentValue."Page No.") or (CurrLineBottomPage = 0) then begin
    //                 CurrLineBottomPage := DocumentValue."Page No.";
    //                 Clear(CurrLineBottomPos);
    //             end;

    //             if CurrLineTopPage = DocumentValue."Page No." then
    //                 if (CurrLineTopPos > DocumentValue.Top) or (CurrLineTopPos = 0) then
    //                     CurrLineTopPos := DocumentValue.Top;

    //             if CurrLineBottomPage = DocumentValue."Page No." then
    //                 if (CurrLineBottomPos < DocumentValue.Bottom) or (CurrLineBottomPos = 0) then
    //                     CurrLineBottomPos := DocumentValue.Bottom;
    //         //END;
    //         until DocumentValue.Next() = 0;
    // end;

    local procedure GetStartAndEndCaption(var CaptionStartWord: array[100] of Record "CDC Document Word" temporary; var CaptionEndWord: array[100] of Record "CDC Document Word" temporary; "Field": Record "CDC Template Field"; DocNo: Code[20]; PageNo: Integer): Boolean
    var
        CDCTemplateFieldCaption: Record "CDC Template Field Caption";
        CaptureEngine: Codeunit "CDC Capture Engine";
    begin
        Clear(CaptionStartWord);
        Clear(CaptionEndWord);

        CDCTemplateFieldCaption.SetRange("Template No.", Field."Template No.");
        CDCTemplateFieldCaption.SetRange(Type, Field.Type);
        CDCTemplateFieldCaption.SetRange(Code, Field.Code);
        if CDCTemplateFieldCaption.FindSet() then
            repeat
                if CaptureEngine.FindCaption(DocNo, PageNo, Field, CDCTemplateFieldCaption, CaptionStartWord, CaptionEndWord) then
                    exit(true);
            until (CDCTemplateFieldCaption.Next() = 0) or ((CaptionStartWord[1].Word <> '') and (CaptionEndWord[1].Word <> ''));
    end;

    local procedure GetPositionOfCaption(CurrPage: Record "CDC Document Page"; CaptionTemplateField: Record "CDC Template Field"; CaptionStartWord: Record "CDC Document Word"; CaptionEndWord: Record "CDC Document Word"; DocumentValue: Record "CDC Document Value"; var FieldLeft: Integer; var FieldWidth: Integer; var Bottom: Integer; var Top: Integer) CaptionValueFound: Boolean
    var
        CaptureEngine: Codeunit "CDC Capture Engine";
    begin
        CDCTemplate.Get(CaptionTemplateField."Template No.");

        //Hole Positionen der caption
        CaptionValueFound := CaptureMgt.CaptureFromPos(CurrPage, CaptionTemplateField, 0, false, CaptionStartWord.Top, CaptionStartWord.Left,
          CaptionEndWord.Bottom, CaptionEndWord.Right, DocumentValue) <> '';

        if CaptionValueFound then begin
            FieldLeft := CaptionStartWord.Left +
            Round(CaptionTemplateField."Caption Offset X" * CaptureEngine.GetDPIFactor(CaptionTemplateField."Offset DPI", CurrPage."TIFF Image Resolution"), 1);

            if not CDCTemplate."First Table Line Has Captions" then
                Bottom := CaptionStartWord.Top
            else
                if CaptionStartWord.Bottom > Bottom then
                    Bottom := CaptionStartWord.Bottom;

            if FieldWidth < CaptionEndWord.Right - CaptionStartWord.Left then
                FieldWidth := CaptionEndWord.Right - CaptionStartWord.Left;

            Top := CaptionStartWord.Top;
        end;
    end;

    local procedure CaptureTableCell(var CDCTemplate: Record "CDC Template"; var "Page": Record "CDC Document Page"; var "Field": Record "CDC Template Field"; LineNo: Integer; Top: Integer; Left: Integer; Bottom: Integer; Right: Integer): Integer
    var
        Value: Record "CDC Document Value";
    begin
        if (Right - Left <= 0) or (Bottom - Top <= 0) then
            exit;

        CaptureMgt.CaptureFromPos(Page, Field, LineNo, true, Top, Left, Bottom, Right, Value);
        Value.Find('=');

        if (Value.IsBlank()) or TableCellAlreadyCaptured(CDCTemplate, Page, Value) then
            Value.Delete()
        else
            exit(Value.Bottom);
    end;

    local procedure TableCellAlreadyCaptured(var CDCTemplate: Record "CDC Template"; var "Page": Record "CDC Document Page"; var Value: Record "CDC Document Value"): Boolean
    var
        Value2: Record "CDC Document Value";
        CaptureEngine: Codeunit "CDC Capture Engine";
    begin
        Value2.SetCurrentKey("Document No.", "Is Value", Type, "Page No.");
        if not CDCTemplate."First Table Line Has Captions" then
            Value2.SetRange("Is Value", true);
        Value2.SetRange("Document No.", Page."Document No.");
        Value2.SetRange(Type, Value2.Type::Line);
        Value2.SetRange("Page No.", Value."Page No.");

        Value.Top := Value.Top + Round((Value.Bottom - Value.Top) / 2, 1);
        Value.Left := Value.Left + 3;

        if Value2.FindSet(false, false) then
            repeat
                if (not ((Value2.Code = Value.Code) and (Value2."Line No." = Value."Line No."))) then
                    if CaptureEngine.IntersectsWith(Value, Value2) then
                        exit(true);
            until Value2.Next() = 0;
    end;

    local procedure IsFieldValid(var CaptionField: Record "CDC Template Field"; Document: Record "CDC Document"; LineNo: Integer): Boolean
    var
        "Field": Record "CDC Template Field";
        Value: Record "CDC Document Value";
    begin
        case CaptionField."Data Type" of
            Field."Data Type"::Number:
                if (not CaptionField.Required) then
                    if Value.Get(Document."No.", true, CaptionField.Code, LineNo) then
                        if not Value."Is Valid" then
                            exit
                        else
                            exit(CaptureMgt.ParseNumber(Field, Value."Value (Text)", Value."Value (Decimal)"));
            Field."Data Type"::Text:
                if Value.Get(Document."No.", true, CaptionField.Code, LineNo) then
                    exit(IsValidText(CaptionField, Value."Value (Text)", Document."No."));
            Field."Data Type"::Date:
                if Value.Get(Document."No.", true, CaptionField.Code, LineNo) then
                    exit(IsValidDate(CaptionField, Value."Value (Date)"));
            Field."Data Type"::Lookup:
                if Value.Get(Document."No.", true, CaptionField.Code, LineNo) then
                    exit(IsValidLookup(CaptionField, Value."Value (Text)", Document."No."));
        end;
        exit(true);
    end;

    local procedure FillSortedFieldBuffer(var TempSortedDocumentField: Record "CDC Temp. Document Field"; var MandatoryField: Record "CDC Temp. Document Field"; TempDocLine: Record "CDC Temp. Document Line" temporary)
    var
        CDCTemplateField: Record "CDC Template Field";
    begin
        CDCTemplateField.SetRange(CDCTemplateField."Template No.", TempDocLine."Template No.");
        CDCTemplateField.SetRange(CDCTemplateField.Type, CDCTemplateField.Type::Line);
        if CDCTemplateField.FindSet() then
            repeat
                if (CDCTemplateField."Advanced Line Recognition Type" <> CDCTemplateField."Advanced Line Recognition Type"::Default) and
                   (StrLen(CDCTemplateField.Formula) = 0) and (StrLen(CDCTemplateField.GetFixedValue()) = 0) then begin
                    TempSortedDocumentField."Document No." := TempDocLine."Document No.";
                    TempSortedDocumentField."Sort Order" := CDCTemplateField.Sorting;
                    TempSortedDocumentField."Field Code" := CDCTemplateField.Code;
                    TempSortedDocumentField.Insert();
                end else
                    if CDCTemplateField.Required then begin
                        MandatoryField."Document No." := TempDocLine."Document No.";
                        MandatoryField."Sort Order" := CDCTemplateField.Sorting;
                        MandatoryField."Field Code" := CDCTemplateField.Code;
                        MandatoryField.Insert();
                    end;
            until CDCTemplateField.Next() = 0;

    end;

    local procedure GetStopLineRecognitionPositions(var StopPos: array[100] of Integer; CurrPageNo: Integer; Document: Record "CDC Document")
    var
        "Field": Record "CDC Template Field";
        Value: Record "CDC Document Value";
    begin
        Field.Reset();
        Field.SetCurrentKey("Template No.", Type, "Sort Order");
        Field.SetRange("Template No.", Document."Template No.");
        Field.SetRange(Type, Field.Type::Header);
        Field.SetFilter("Stop Lines Recognition", '>%1', Field."Stop Lines Recognition"::" ");
        if Field.Find() then
            repeat
                Value.Reset();
                Value.SetRange("Document No.", Document."No.");
                Value.SetRange(Type, Field.Type);
                Value.SetRange(Code, Field.Code);
                Value.SetRange("Page No.", CurrPageNo);

                case Field."Stop Lines Recognition" of
                    Field."Stop Lines Recognition"::"If Caption is on same line",
                  Field."Stop Lines Recognition"::"If Caption is on same line (continue on next page)":
                        Value.SetRange("Is Value", false);
                    Field."Stop Lines Recognition"::"If Value is on same line",
                  Field."Stop Lines Recognition"::"If Value is on same line (continue on next page)":
                        Value.SetRange("Is Value", true);
                    Field."Stop Lines Recognition"::"If Caption or Value is on same line",
                  Field."Stop Lines Recognition"::"If Caption or Value is on same line (continue on next page)":
                        Value.SetRange("Is Value");
                end;

                Value.SetFilter(Top, '>%1', 0);
                if Value.FindFirst() then
                    if (StopPos[Value."Page No."] = 0) or (StopPos[Value."Page No."] > Value.Top) then
                        if (not (Value.Left = Value.Right) and (Value.Bottom = Value.Top)) then
                            StopPos[Value."Page No."] := Value.Top;
            until Field.Next() = 0;
    end;

    local procedure CleanupPrevValues(Document: Record "CDC Document")
    var
        DocumentValue: Record "CDC Document Value";
    begin
        DocumentValue.SetRange("Document No.", Document."No.");
        DocumentValue.SetRange(Type, DocumentValue.Type::Line);
        DocumentValue.DeleteAll();
        ;
    end;

    local procedure CleanupTempValues(Document: Record "CDC Document")
    var
        DocumentValue: Record "CDC Document Value";
    begin
        // Clean up temporary created values
        DocumentValue.SetRange("Document No.", Document."No.");
        DocumentValue.SetRange(Type, DocumentValue.Type::Line);
        DocumentValue.SetFilter("Line No.", '1000..');
        DocumentValue.DeleteAll();
        ;
    end;

    // The following functions are a copy of the same functions in the Capture Management Codeunit, where they are defined as "local"



    // local procedure IsValidNumber(var "Field": Record "CDC Template Field"; Number: Decimal): Boolean
    // var
    //     FieldRule: Record "CDC Template Field Rule";
    //     TempTemplateField: Record "CDC Template Field" temporary;
    // begin
    //     if Field."Codeunit ID: Capture Value" <> 0 then
    //         exit(TestCaptureValue(Field, FieldRule, Format(Number)));

    //     if (Number = 0) and Field.Required then
    //         exit(false);

    //     CaptureMgt.FilterRule(Field, FieldRule);

    //     TempTemplateField."Fixed Value (Decimal)" := Number;
    //     TempTemplateField.Insert;

    //     if FieldRule.FindSet() then
    //         repeat
    //             if FieldRule.Rule <> '' then begin
    //                 TempTemplateField.SetFilter("Fixed Value (Decimal)", FieldRule.Rule);
    //                 if TempTemplateField.IsEmpty then
    //                     exit(false);
    //             end;
    //         until FieldRule.Next() = 0;

    //     exit(true);
    // end;

    local procedure IsValidDate(var "Field": Record "CDC Template Field"; Date: Date): Boolean
    var
        FieldRule: Record "CDC Template Field Rule";
    begin
        if Field."Codeunit ID: Capture Value" <> 0 then
            exit(TestCaptureValue(Field, FieldRule, Format(Date)));

        if (Date = 0D) then
            exit(not Field.Required);

        if Format(Field."Validation Dateformula From") <> '' then
            if Date < CalcDate(Field."Validation Dateformula From", Today) then
                exit(false);

        if Format(Field."Validation Dateformula To") <> '' then
            if Date > CalcDate(Field."Validation Dateformula To", Today) then
                exit(false);

        if Date < 17540101D then
            exit(false);

        exit(true);
    end;

    local procedure IsValidText(var "Field": Record "CDC Template Field"; Text: Text[250]; DocumentNo: Code[20]): Boolean
    var
        FieldRule: Record "CDC Template Field Rule";
        TempValue: Record "CDC Document Value" temporary;
        RegEx: Codeunit "CDC RegEx Management";
        IsValid: Boolean;
    begin
        Text := UpperCase(Text);

        if Field."Codeunit ID: Capture Value" <> 0 then
            if TestCaptureValue(Field, FieldRule, Text) then
                exit(true);

        CaptureMgt.FilterRule(Field, FieldRule);
        if not FieldRule.FindFirst() then
            exit((Text <> '') or (not Field.Required));

        if Text = '' then
            exit(not Field.Required);

        TempValue."Value (Text)" := Text;
        TempValue.Insert();

        repeat
            FieldRule.Rule := UpperCase(FieldRule.Rule);
            if (StrPos(FieldRule.Rule, '<') <> 0) or
              (StrPos(FieldRule.Rule, '>') <> 0) or
              (StrPos(FieldRule.Rule, '|') <> 0) or
              (StrPos(FieldRule.Rule, '*') <> 0) or
              (StrPos(FieldRule.Rule, '&') <> 0)
            then begin
                TempValue.SetFilter("Value (Text)", FieldRule.Rule);
                IsValid := not TempValue.IsEmpty;
            end else begin
                if RegEx.IsMatch(Text, FieldRule.Rule) then
                    if Field."Codeunit ID: Capture Value" <> 0 then
                        IsValid := TestCaptureValue(Field, FieldRule, Text)
                    else
                        IsValid := true;

                if IsValid and Field."Enable Rule Generation" then begin
                    ClearFldRuleCreatedFromMaster(FieldRule, DocumentNo);

                    // Several rules could have been copied from the master template. Delete these when a rule matches the found value
                    DelFldRulesCreatedFromMaster(FieldRule."Entry No.");
                end;
            end;
        until (FieldRule.Next() = 0) or (IsValid);

        exit(IsValid);
    end;

    local procedure IsValidLookup("Field": Record "CDC Template Field"; Value: Text[250]; DocumentNo: Code[20]): Boolean
    begin
        exit(IsValidText(Field, Value, DocumentNo));
    end;

    // local procedure IsValidBoolean(var "Field": Record "CDC Template Field"; Boolean: Boolean): Boolean
    // begin
    //     exit(true);
    // end;

    local procedure TestCaptureValue("Field": Record "CDC Template Field"; Rule: Record "CDC Template Field Rule"; Value: Text[1024]): Boolean
    var
        CDCTempCaptureFieldVal: Record "CDC Temp. Capture Field Valid.";
    begin
        CDCTempCaptureFieldVal."Field Type" := Field.Type;
        CDCTempCaptureFieldVal."Field Code" := Field.Code;
        CDCTempCaptureFieldVal."File Rule Entry No." := Rule."Entry No.";
        CDCTempCaptureFieldVal.Rule := Rule.Rule;
        CDCTempCaptureFieldVal.Value := CopyStr(Value, 1, MaxStrLen(CDCTempCaptureFieldVal.Value));
        CODEUNIT.Run(Field."Codeunit ID: Capture Value", CDCTempCaptureFieldVal);
        exit(CDCTempCaptureFieldVal."Is Valid");
    end;

    local procedure ClearFldRuleCreatedFromMaster(var FieldRule: Record "CDC Template Field Rule"; DocumentNo: Code[20])
    begin
        if FieldRule."Created from Master Template" then begin
            FieldRule."Created from Master Template" := false;
            FieldRule."Document No." := DocumentNo;
            FieldRule.Modify(true);
        end;
    end;

    local procedure DelFldRulesCreatedFromMaster(SkipEntryNo: Integer)
    var
        FieldRule: Record "CDC Template Field Rule";
    begin
        FieldRule.SetRange("Created from Master Template", true);
        FieldRule.SetFilter("Entry No.", '<>%1', SkipEntryNo);
        if not FieldRule.IsEmpty then
            FieldRule.DeleteAll(true);
    end;

    [IntegrationEvent(TRUE, false)]
    local procedure OnAfterStandardLineRecognition(var Document: Record "CDC Document"; var Handled: Boolean)
    begin
    end;
}

