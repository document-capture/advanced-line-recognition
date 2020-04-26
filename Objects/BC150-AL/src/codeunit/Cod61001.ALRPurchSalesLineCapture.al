codeunit 61001 "ALR Purch/Sales Line Capture"
{
    // -----------------------------------------------------
    // CKL Software GmbH
    // 
    // Ver Date     Usr Change
    // -----------------------------------------------------
    // 001 20180326 SRA Initial Commit
    // 002 20180325 SRA New functions
    // 007 20190613 SRA New Object number due to conflicts with the default training objects
    // 008 20191106 SRA Bug with Page 0 error message fixed
    //                  Bug fixed that resulted in wrong data when a page break was inside lines of a position
    // -----------------------------------------------------

    TableNo = "CDC Document";

    trigger OnRun()
    begin
        Document := Rec;
        Code;
    end;

    var
        Text001: Label 'Please create a %1 with %2 = ''%3''';
        Document: Record "CDC Document";
        CaptureMgt: Codeunit "CDC Capture Management";
        DocumentComment: Record "CDC Document Comment";
        Text002: Label 'Zeilenidentifikationsfeld %1 - %2 verwendet!';
        MandatoryFieldBuffer: Record "CDC Temp. Document Field" temporary;

    procedure "Code"()
    var
        TempDocLine: Record "CDC Temp. Document Line" temporary;
        TemplateField: Record "CDC Template Field";
        TempSortedDocumentField: Record "CDC Temp. Document Field" temporary;
        Template: Record "CDC Template";
    begin
        if not Template.Get(Document."Template No.") then
            exit;

        //RUN STANDARD LINE CAPTURING CODEUNIT
        if Template."Original Line Capt. Codeunit" = 0 then
            CODEUNIT.Run(CODEUNIT::"CDC Purch./Sales - Line Capt.", Document)
        else
            CODEUNIT.Run(Template."Original Line Capt. Codeunit", Document);

        //BUILD TEMPORARY LINE TABLE AND LOOP LINES
        Document.BuildTempLinesTable(TempDocLine);

        if TempDocLine.FindSet then begin
            FillSortedFieldBuffer(TempSortedDocumentField, MandatoryFieldBuffer, TempDocLine);
            repeat
                TempSortedDocumentField.SetCurrentKey("Document No.", "Sort Order");
                if TempSortedDocumentField.FindFirst then
                    repeat
                        with TemplateField do begin
                            Get(TempDocLine."Template No.", TemplateField.Type::Line, TempSortedDocumentField."Field Code");
                            case "Advanced Line Recognition Type" of
                                "Advanced Line Recognition Type"::LinkedToAnchorField:
                                    FindValueFromOffsetField(TempDocLine, TemplateField);
                                "Advanced Line Recognition Type"::FindFieldByCaptionInPosition:
                                    FindValueByCaptionInPosition(TempDocLine, TemplateField);
                                "Advanced Line Recognition Type"::FindFieldByColumnHeading:
                                    FindFieldByColumnHeading(TempDocLine, TemplateField);
                            end;
                        end;
                    until TempSortedDocumentField.Next = 0;
                FindSubstitutionFieldValue(TempDocLine);
                GetValueFromPreviousValue(TempDocLine);
            until TempDocLine.Next = 0;
        end;
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
        //Get Line Identification Field Position
        if not OffsetSourceField.Get(TempDocLine."Template No.", OffsetSourceField.Type::Line, OffsetField."Anchor Field") then
            exit;

        // Get current value record of offset source field
        if not OffsetSourceFieldValue.Get(TempDocLine."Document No.", true, OffsetSourceField.Code, TempDocLine."Line No.") then
            exit;

        CurrPage.Get(Document."No.", OffsetSourceFieldValue."Page No.");

        with OffsetSourceFieldValue do begin
            // Create offset area for value capturing
            CurrTop := Top + OffsetField."Offset Top";
            CurrLeft := Left + OffsetField."Offset Left";
            CurrBottom := CurrTop + OffsetField."Offset Bottom";
            CurrRight := CurrLeft + OffsetField."Offset Right";
            CaptureMgt.CaptureFromPos(CurrPage, OffsetField, TempDocLine."Line No.", true, CurrTop, CurrLeft, CurrBottom, CurrRight, DocumentValue);
            if DocumentValue.Get(TempDocLine."Document No.", true, OffsetField.Code, TempDocLine."Line No.") then
                if ((DocumentValue."Value (Text)" = '') and (DocumentValue."Value (Decimal)" = 0)) or (not DocumentValue."Is Valid") then
                    DocumentValue.Delete;
        end;
    end;

    local procedure FindValueByCaptionInPosition(var TempDocLine: Record "CDC Temp. Document Line" temporary; var CurrField: Record "CDC Template Field"): Boolean
    var
        DocumentValue: Record "CDC Document Value";
        DocumentValueCopy: Record "CDC Document Value";
        lCurrPage: Record "CDC Document Page";
        NextPos: Integer;
        CaptureEngine: Codeunit "ALR CDC Capture Engine";
        Word: Text[1024];
        lFromTopPos: Integer;
        lFromTopPage: Integer;
        lToBottomPos: Integer;
        lToBottomPage: Integer;
        i: Integer;
    begin
        if DocumentValue.Get(TempDocLine."Document No.", true, CurrField.Code, TempDocLine."Line No.") then
            DocumentValue.Delete;

        Clear(Word);

        // Get Position of caption
        if CurrField."Field Position" = CurrField."Field Position"::AboveAnchor then
            GetRangeToPrevLine(TempDocLine, lFromTopPage, lFromTopPos, lToBottomPage, lToBottomPos)
        else
            GetRangeToNextLine(TempDocLine, lFromTopPage, lFromTopPos, lToBottomPage, lToBottomPos);

        for i := lFromTopPage to lToBottomPage do begin
            lCurrPage.Get(Document."No.", i);

            //IF lFromTopPage < lToBottomPage THEN
            if i < lToBottomPage then
                CaptureEngine.SetLineRegion(i, lFromTopPos, i, lCurrPage."Bottom Word Pos.")
            else
                if (i > lFromTopPage) and (i < lToBottomPage) then
                    CaptureEngine.SetLineRegion(i, 0, i, lCurrPage."Bottom Word Pos.")
                else
                    if lFromTopPos > lToBottomPos then
                        CaptureEngine.SetLineRegion(i, 0, i, lToBottomPos)
                    else
                        CaptureEngine.SetLineRegion(i, lFromTopPos, i, lToBottomPos);


            CurrField."Caption Offset X" := CurrField."ALR Value Caption Offset X";
            CurrField."Caption Offset Y" := CurrField."ALR Value Caption Offset Y";
            CurrField."Typical Field Width" := CurrField."ALR Typical Value Field Width";

            Word := CaptureEngine.CaptureField(Document, lCurrPage."Page No.", CurrField, false);

            if Word <> '' then begin
                if (DocumentValue.Get(Document."No.", true, CurrField.Code, 0)) then begin
                    DocumentValueCopy := DocumentValue;
                    DocumentValueCopy."Line No." := TempDocLine."Line No.";
                    DocumentValueCopy.Type := DocumentValueCopy.Type::Line;
                    DocumentValueCopy.Insert;
                    DocumentValue.Delete;
                end;
                CaptureMgt.UpdateFieldValue(Document."No.", TempDocLine."Page No.", TempDocLine."Line No.", CurrField, Word, false, false);

                exit(true);
            end;
        end;
    end;

    local procedure FindFieldByColumnHeading(var TempDocLine: Record "CDC Temp. Document Line" temporary; var CurrField: Record "CDC Template Field")
    var
        Template: Record "CDC Template";
        DocumentValue: Record "CDC Document Value";
        DocumentValueBuffer: Record "CDC Document Value" temporary;
        DocumentValueNew: Record "CDC Document Value";
        CaptionStartWord: array[100] of Record "CDC Document Word";
        CaptionEndWord: array[100] of Record "CDC Document Word";
        CaptionPage: Record "CDC Document Page";
        CurrPage: Record "CDC Document Page";
        CaptionValue: Record "CDC Document Value";
        CaptionPageNo: Integer;
        CaptionFound: Boolean;
        PageStop: Boolean;
        lFromTopPos: Integer;
        lFromTopPage: Integer;
        lToBottomPos: Integer;
        lToBottomPage: Integer;
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
        if not Template.Get(TempDocLine."Template No.") then
            exit;

        // Delete old values
        if DocumentValue.Get(TempDocLine."Document No.", true, CurrField.Code, TempDocLine."Line No.") then
            DocumentValue.Delete;

        // Find the Caption position on current or previous pages
        CaptionPageNo := TempDocLine."Page No.";
        repeat
            CaptionFound := GetStartAndEndCaption(CaptionStartWord, CaptionEndWord, CurrField, TempDocLine."Document No.", CaptionPageNo);
            if not CaptionFound then
                CaptionPageNo -= 1;
        until (CaptionPageNo = 0) or CaptionFound;

        if (not CaptionFound) then
            exit;

        //BUG
        //CaptionPageNo := 1;
        CaptionPage.Get(TempDocLine."Document No.", CaptionPageNo);
        GetPositionOfCaption(CaptionPage, CurrField, CaptionStartWord[1], CaptionEndWord[1], CaptionValue, FieldLeft, FieldWidth, Bottom, Top);

        // Hole Position der nächsten
        GetRangeToNextLine(TempDocLine, lFromTopPage, lFromTopPos, lToBottomPage, lToBottomPos);
        //BUG
        //lFromTopPage := 1;
        //------------------------------------------------------
        NewBottom := 0;
        LineNo := 1000 * TempDocLine."Page No.";
        LineHeight := 12;

        Top := lFromTopPos;
        Bottom := Top + LineHeight;

        PageStop := false;
        CurrPage.Get(TempDocLine."Document No.", lFromTopPage);
        repeat
            LineNo += 1;
            Right := FieldLeft + FieldWidth;
            NewBottom := CaptureTableCell(Template, Document, CurrPage, CurrField, LineNo, Top, FieldLeft, Bottom, Right);
            if NewBottom > 0 then begin
                if NewBottom > Bottom then
                    Bottom := NewBottom;

                if not IsFieldValid(CurrField, Document, LineNo) then begin
                    DocumentValue.Reset;
                    DocumentValue.SetRange("Document No.", Document."No.");
                    DocumentValue.SetRange("Line No.", LineNo);
                    DocumentValue.DeleteAll(true);
                end else begin
                    //PageStop := TRUE;
                    LastFoundLineNo := LineNo;
                    PageStop := CurrField."Field Position" = CurrField."Field Position"::AboveAnchor;
                    if DocumentValue.Get(TempDocLine."Document No.", true, CurrField.Code, LastFoundLineNo) then begin
                        DocumentValueBuffer := DocumentValue;
                        DocumentValueBuffer.Insert;
                        DocumentValue.Delete;
                    end;
                end;
            end;

            if not PageStop then begin
                Top := Bottom;
                Bottom := Top + LineHeight;//CaptureEngine.GetNextBottom(DocumentPage,Bottom,LineHeight);

                if (Bottom > CurrPage."Bottom Word Pos.") and (CurrPage."Page No." < lToBottomPage) then begin
                    //Neue Seite - es müssen Variablen zurückgesetzt werden
                    CurrPage.Get(CurrPage."Document No.", CurrPage."Page No." + 1);
                    CaptionPageNo := CurrPage."Page No.";
                    LineNo := 1000 * CurrPage."Page No.";
                    if GetStartAndEndCaption(CaptionStartWord, CaptionEndWord, CurrField, TempDocLine."Document No.", CaptionPageNo) then begin
                        CaptionPage.Get(TempDocLine."Document No.", CurrPage."Page No.");
                        if GetPositionOfCaption(CaptionPage, CurrField, CaptionStartWord[1], CaptionEndWord[1], CaptionValue, FieldLeft, FieldWidth, Bottom, Top) then begin
                            Bottom := Top + LineHeight;
                            //LineNo := 1000 * TempDocLine."Page No.";
                        end;

                    end;
                end else
                    if (Bottom > CurrPage."Bottom Word Pos.") or ((Bottom > lToBottomPos) and (CurrPage."Page No." = lToBottomPage)) then
                        PageStop := true;
            end;
        until PageStop;

        //Zeilennr. speichern
        if DocumentValueBuffer.Get(TempDocLine."Document No.", true, CurrField.Code, LastFoundLineNo) then begin
            DocumentValueNew := DocumentValueBuffer;
            DocumentValueNew."Line No." := TempDocLine."Line No.";
            DocumentValueNew.Insert;
            DocumentValueBuffer.Delete;
        end;
    end;

    local procedure FindSubstitutionFieldValue(var TempDocLine: Record "CDC Temp. Document Line" temporary)
    var
        TemplateField: Record "CDC Template Field";
        DocumentValue: Record "CDC Document Value";
        SubstitutionDocumentValue: Record "CDC Document Value";
        SubstitutionField: Record "CDC Template Field";
    begin
        // Function goes through all field, setted up with substitution fields.
        // It checks if the value of the current field is empty and updates the value with the value of the substitution field (if exists).
        TemplateField.SetRange("Template No.", TempDocLine."Template No.");
        TemplateField.SetFilter("Substitution Field", '<>%1', '');
        if TemplateField.FindSet then
            repeat
                if not DocumentValue.Get(TempDocLine."Document No.", true, TemplateField.Code, TempDocLine."Line No.") then
                    if SubstitutionField.Get(TempDocLine."Template No.", SubstitutionField.Type::Line, TemplateField."Substitution Field") then
                        if SubstitutionDocumentValue.Get(TempDocLine."Document No.", true, SubstitutionField.Code, TempDocLine."Line No.") then begin
                            CaptureMgt.UpdateFieldValue(TempDocLine."Document No.", TempDocLine."Page No.", TempDocLine."Line No.", TemplateField, SubstitutionDocumentValue."Value (Text)", false, false);
                            if DocumentValue.Get(TempDocLine."Document No.", true, TemplateField.Code, TempDocLine."Line No.") then begin
                                DocumentValue.Top := SubstitutionDocumentValue.Top;
                                DocumentValue.Bottom := SubstitutionDocumentValue.Bottom;
                                DocumentValue.Left := SubstitutionDocumentValue.Left;
                                DocumentValue.Right := SubstitutionDocumentValue.Right;
                                DocumentValue.Modify;
                            end;
                        end;
            until TemplateField.Next = 0;
    end;

    local procedure GetValueFromPreviousValue(var TempDocLine: Record "CDC Temp. Document Line" temporary)
    var
        TemplateField: Record "CDC Template Field";
        DocumentValue: Record "CDC Document Value";
    begin
        // Function goes through all field, setted up with substitution fields.
        // It checks if the value of the current field is empty and updates the value with the value of the substitution field (if exists).
        TemplateField.SetRange("Template No.", TempDocLine."Template No.");
        TemplateField.SetRange("Get Value from Previous Value", true);
        if TemplateField.FindSet then
            repeat
                if not DocumentValue.Get(TempDocLine."Document No.", true, TemplateField.Code, TempDocLine."Line No.") then
                    if DocumentValue.Get(TempDocLine."Document No.", true, TemplateField.Code, TempDocLine."Line No." - 1) then
                        CaptureMgt.UpdateFieldValue(TempDocLine."Document No.", TempDocLine."Page No.", TempDocLine."Line No.", TemplateField, DocumentValue."Value (Text)", false, false);
            until TemplateField.Next = 0;
    end;

    local procedure GetRangeToNextLine(var TempDocLine: Record "CDC Temp. Document Line"; var NextLineTopPage: Integer; var NextLineTopPos: Integer; var NextLineBottomPage: Integer; var NextLineBottomPos: Integer)
    var
        DocumentValue: Record "CDC Document Value";
        CurrPage: Record "CDC Document Page";
        StopPos: array[100] of Integer;
    begin
        // This function calculates the range until the next position/line
        Clear(NextLineTopPage);
        Clear(NextLineTopPos);
        Clear(NextLineBottomPage);
        Clear(NextLineBottomPos);

        with DocumentValue do begin
            SetCurrentKey("Document No.", "Is Value", Code, "Line No.");
            SetRange("Document No.", TempDocLine."Document No.");
            SetRange("Is Value", true);
            SetRange(Type, Type::Line);
            SetFilter("Page No.", '>%1', 0);

            GetCurrLinePosition(DocumentValue, TempDocLine."Line No.", NextLineTopPage, NextLineTopPos, NextLineBottomPage, NextLineBottomPos);

            // Filter for next line
            SetRange("Line No.", TempDocLine."Line No." + 1);
            if FindSet then begin
                repeat
                    if (NextLineBottomPage < "Page No.") or (NextLineBottomPage = 0) then begin
                        NextLineBottomPage := "Page No.";
                        NextLineBottomPos := 0;
                    end;

                    if NextLineBottomPage = "Page No." then begin
                        if (NextLineBottomPos < Bottom) or (NextLineBottomPos = 0) then
                            NextLineBottomPos := Bottom;
                    end;
                until Next = 0;
            end else begin
                // As there is no next line, calculate to next header value or bottom of current page
                SetCurrentKey("Document No.", "Is Value", Code, "Line No.");
                SetRange("Document No.", TempDocLine."Document No.");
                SetRange("Is Value", false);
                SetRange(Type, Type::Header);
                SetFilter(Top, '>%1', NextLineBottomPos);
                SetRange("Line No.", 0);
                if FindSet(false, false) then begin
                    if "Page No." > NextLineBottomPage then begin
                        NextLineBottomPage := "Page No.";
                        //??? NextLineTopPos := 0;
                        NextLineTopPage := "Page No.";
                    end;
                    NextLineBottomPos := Top
                end else begin
                    CurrPage.Get(TempDocLine."Document No.", NextLineBottomPage);
                    NextLineBottomPos := CurrPage."Bottom Word Pos.";
                end;
            end;
        end;

        GetStopLineRecognitionPositions(StopPos, NextLineBottomPage, NextLineBottomPos);
        if (StopPos[NextLineBottomPage] > 0) and (StopPos[NextLineBottomPage] <= NextLineBottomPos) then
            NextLineBottomPos := StopPos[NextLineBottomPage];
    end;

    local procedure GetRangeToPrevLine(var TempDocLine: Record "CDC Temp. Document Line"; var RangeTopPage: Integer; var RangeTopPos: Integer; var RangeBottomPage: Integer; var RangeBottomPos: Integer)
    var
        DocumentValue: Record "CDC Document Value";
        CurrPage: Record "CDC Document Page";
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

        with DocumentValue do begin
            SetCurrentKey("Document No.", "Is Value", Code, "Line No.");
            SetRange("Document No.", TempDocLine."Document No.");
            SetRange("Is Value", true);
            SetRange(Type, Type::Line);
            SetFilter("Page No.", '>%1', 0);

            GetCurrLinePosition(DocumentValue, TempDocLine."Line No.", CurrLineTopPage, CurrLineTopPos, CurrLineBottomPage, CurrLineBottomPos);

            // Filter for Prev line
            SetRange("Line No.", TempDocLine."Line No." - 1);
            if FindSet then begin
                repeat
                    if ("Page No." < PrevLineTopPage) or (PrevLineTopPage = 0) then begin
                        PrevLineTopPage := "Page No.";
                        Clear(PrevLineTopPos);
                    end;

                    if ("Page No." > PrevLineBottomPage) or (PrevLineBottomPage = 0) then begin
                        PrevLineBottomPage := "Page No.";
                        Clear(PrevLineBottomPos);
                    end;

                    if PrevLineTopPage = "Page No." then
                        if (Top < PrevLineTopPos) or (PrevLineTopPos = 0) then
                            PrevLineTopPos := Top;

                    if PrevLineBottomPage = "Page No." then
                        if (Bottom > PrevLineBottomPos) or (PrevLineBottomPos = 0) then
                            PrevLineBottomPos := Bottom;
                until Next = 0;
            end else begin
                // As there is no Prev line, calculate to Prev header value or bottom of current page
                SetCurrentKey("Document No.", "Is Value", Code, "Line No.");
                SetRange("Document No.", TempDocLine."Document No.");
                SetRange("Is Value", false);
                SetRange(Type, Type::Header);
                SetFilter("Page No.", '<=%1', "Page No.");
                SetFilter(Top, '<%1', CurrLineTopPos);
                if FindSet(false, false) then begin
                    PrevLineBottomPos := Bottom;
                    PrevLineBottomPage := "Page No.";
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
    end;

    local procedure GetCurrLinePosition(var DocumentValue: Record "CDC Document Value"; LineNo: Integer; var CurrLineTopPage: Integer; var CurrLineTopPos: Integer; var CurrLineBottomPage: Integer; var CurrLineBottomPos: Integer)
    begin
        with DocumentValue do begin
            // Filter for current line
            SetRange("Line No.", LineNo);
            if FindSet then
                repeat
                    if MandatoryFieldBuffer.Get(DocumentValue.GetFilter("Document No."), Code) then begin
                        if ("Page No." < CurrLineTopPage) or (CurrLineTopPage = 0) then begin
                            CurrLineTopPage := "Page No.";
                            Clear(CurrLineTopPos);
                        end;

                        if ("Page No." > CurrLineBottomPage) or (CurrLineBottomPage = 0) then begin
                            CurrLineBottomPage := "Page No.";
                            Clear(CurrLineBottomPos);
                        end;

                        if CurrLineTopPage = "Page No." then
                            if (Top < CurrLineTopPos) or (CurrLineTopPos = 0) then
                                CurrLineTopPos := Top;

                        if CurrLineBottomPage = "Page No." then
                            if (Bottom > CurrLineBottomPos) or (CurrLineBottomPos = 0) then
                                CurrLineBottomPos := Bottom;
                    end;
                until Next = 0;
        end;
    end;

    local procedure GetLinePositions(DocumentNo: Code[20]; LineNo: Integer; var CurrLineTopPage: Integer; var CurrLineTopPos: Integer; var CurrLineBottomPage: Integer; var CurrLineBottomPos: Integer; IsValue: Boolean)
    var
        DocumentValue: Record "CDC Document Value";
    begin
        //Find next lines top position
        DocumentValue.SetCurrentKey("Document No.", "Is Value", Code, "Line No.");
        DocumentValue.SetRange("Document No.", DocumentNo);
        DocumentValue.SetRange("Is Value", IsValue);
        DocumentValue.SetRange(Type, DocumentValue.Type::Line);
        if not IsValue then begin
            DocumentValue.SetRange("Line No.", 0);
            DocumentValue.SetRange("Page No.", 1);
        end else
            DocumentValue.SetRange("Line No.", LineNo);

        DocumentValue.SetFilter(Top, '>0');

        // Identify current lines outer positions
        if DocumentValue.FindSet then
            repeat
                if (CurrLineTopPage > DocumentValue."Page No.") or (CurrLineTopPage = 0) then
                    CurrLineTopPage := DocumentValue."Page No.";
                Clear(CurrLineTopPos);

                if (CurrLineBottomPage < DocumentValue."Page No.") or (CurrLineBottomPage = 0) then begin
                    CurrLineBottomPage := DocumentValue."Page No.";
                    Clear(CurrLineBottomPos);
                end;

                if CurrLineTopPage = DocumentValue."Page No." then
                    if (CurrLineTopPos > DocumentValue.Top) or (CurrLineTopPos = 0) then
                        CurrLineTopPos := DocumentValue.Top;

                if CurrLineBottomPage = DocumentValue."Page No." then
                    if (CurrLineBottomPos < DocumentValue.Bottom) or (CurrLineBottomPos = 0) then
                        CurrLineBottomPos := DocumentValue.Bottom;
            //END;
            until DocumentValue.Next = 0;
    end;

    local procedure GetStartAndEndCaption(var CaptionStartWord: array[100] of Record "CDC Document Word" temporary; var CaptionEndWord: array[100] of Record "CDC Document Word" temporary; "Field": Record "CDC Template Field"; DocNo: Code[20]; PageNo: Integer): Boolean
    var
        TemplateFieldCaption: Record "CDC Template Field Caption";
        CaptureEngine: Codeunit "CDC Capture Engine";
        PrevCaptionStartWord: Record "CDC Document Word";
    begin
        Clear(CaptionStartWord);
        Clear(CaptionEndWord);

        TemplateFieldCaption.SetRange("Template No.", Field."Template No.");
        TemplateFieldCaption.SetRange(Type, Field.Type);
        TemplateFieldCaption.SetRange(Code, Field.Code);
        if TemplateFieldCaption.FindSet then
            repeat
                if CaptureEngine.FindCaption(DocNo, PageNo, Field, TemplateFieldCaption, CaptionStartWord, CaptionEndWord) then
                    exit(true);
            until (TemplateFieldCaption.Next = 0) or ((CaptionStartWord[1].Word <> '') and (CaptionEndWord[1].Word <> ''));
    end;

    local procedure GetPositionOfCaption(CurrPage: Record "CDC Document Page"; CaptionTemplateField: Record "CDC Template Field"; CaptionStartWord: Record "CDC Document Word"; CaptionEndWord: Record "CDC Document Word"; DocumentValue: Record "CDC Document Value"; var FieldLeft: Integer; var FieldWidth: Integer; var Bottom: Integer; var Top: Integer) CaptionValueFound: Boolean
    var
        Template: Record "CDC Template";
        CaptureEngine: Codeunit "CDC Capture Engine";
    begin
        Template.Get(CaptionTemplateField."Template No.");

        //Hole Positionen der caption
        CaptionValueFound := CaptureMgt.CaptureFromPos(CurrPage, CaptionTemplateField, 0, false, CaptionStartWord.Top, CaptionStartWord.Left,
          CaptionEndWord.Bottom, CaptionEndWord.Right, DocumentValue) <> '';

        if CaptionValueFound then begin
            FieldLeft := CaptionStartWord.Left +
            Round(CaptionTemplateField."Caption Offset X" * CaptureEngine.GetDPIFactor(CaptionTemplateField."Offset DPI", CurrPage."TIFF Image Resolution"), 1);

            if not Template."First Table Line Has Captions" then
                Bottom := CaptionStartWord.Top
            else
                if CaptionStartWord.Bottom > Bottom then
                    Bottom := CaptionStartWord.Bottom;

            if FieldWidth < CaptionEndWord.Right - CaptionStartWord.Left then
                FieldWidth := CaptionEndWord.Right - CaptionStartWord.Left;

            Top := CaptionStartWord.Top;
        end;
    end;

    local procedure CaptureTableCell(var Template: Record "CDC Template"; var Document: Record "CDC Document"; var "Page": Record "CDC Document Page"; var "Field": Record "CDC Template Field"; LineNo: Integer; Top: Integer; Left: Integer; Bottom: Integer; Right: Integer): Integer
    var
        Value: Record "CDC Document Value";
    begin
        if (Right - Left <= 0) or (Bottom - Top <= 0) then
            exit;

        CaptureMgt.CaptureFromPos(Page, Field, LineNo, true, Top, Left, Bottom, Right, Value);
        Value.Find('=');

        if (Value.IsBlank) or TableCellAlreadyCaptured(Template, Page, Value) then
            Value.Delete
        else
            exit(Value.Bottom);
    end;

    local procedure TableCellAlreadyCaptured(var Template: Record "CDC Template"; var "Page": Record "CDC Document Page"; var Value: Record "CDC Document Value"): Boolean
    var
        Value2: Record "CDC Document Value";
        CaptureEngine: Codeunit "CDC Capture Engine";
    begin
        Value2.SetCurrentKey("Document No.", "Is Value", Type, "Page No.");
        if not Template."First Table Line Has Captions" then
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
            until Value2.Next = 0;
    end;

    local procedure IsFieldValid(var CaptionField: Record "CDC Template Field"; Document: Record "CDC Document"; LineNo: Integer): Boolean
    var
        "Field": Record "CDC Template Field";
        Value: Record "CDC Document Value";
    begin
        if (CaptionField."Data Type" = Field."Data Type"::Number) and (not CaptionField.Required) then
            if Value.Get(Document."No.", true, CaptionField.Code, LineNo) then
                if not Value."Is Valid" then
                    exit
                else
                    exit(CaptureMgt.ParseNumber(Field, Value."Value (Text)", Value."Value (Decimal)"));

        exit(true);
    end;

    local procedure FillSortedFieldBuffer(var TempSortedDocumentField: Record "CDC Temp. Document Field"; var MandatoryField: Record "CDC Temp. Document Field"; TempDocLine: Record "CDC Temp. Document Line" temporary)
    var
        TemplateField: Record "CDC Template Field";
    begin
        with TemplateField do begin
            SetRange("Template No.", TempDocLine."Template No.");
            SetRange(Type, Type::Line);
            //SETFILTER("Advanced Line Recognition Type", '<>%1',"Advanced Line Recognition Type"::Default);
            if FindSet then
                repeat
                    if "Advanced Line Recognition Type" <> "Advanced Line Recognition Type"::Default then begin
                        TempSortedDocumentField."Document No." := TempDocLine."Document No.";
                        TempSortedDocumentField."Sort Order" := Sorting;
                        TempSortedDocumentField."Field Code" := Code;
                        TempSortedDocumentField.Insert;
                    end else begin
                        if Required then begin
                            MandatoryField."Document No." := TempDocLine."Document No.";
                            MandatoryField."Sort Order" := Sorting;
                            MandatoryField."Field Code" := Code;
                            MandatoryField.Insert;
                        end;
                    end;
                until Next = 0;
        end;
    end;

    local procedure GetStopLineRecognitionPositions(var StopPos: array[100] of Integer; CurrPageNo: Integer; Bottom: Integer)
    var
        "Field": Record "CDC Template Field";
        Value: Record "CDC Document Value";
    begin
        Field.Reset;
        Field.SetCurrentKey("Template No.", Type, "Sort Order");
        Field.SetRange("Template No.", Document."Template No.");
        Field.SetRange(Type, Field.Type::Header);
        Field.SetFilter("Stop Lines Recognition", '>%1', Field."Stop Lines Recognition"::" ");
        if Field.FindSet then
            repeat
                Value.Reset;
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
                if Value.FindFirst then begin
                    if (StopPos[Value."Page No."] = 0) or (StopPos[Value."Page No."] > Value.Top) then
                        StopPos[Value."Page No."] := Value.Top;
                end;
            until Field.Next = 0;
    end;
}

