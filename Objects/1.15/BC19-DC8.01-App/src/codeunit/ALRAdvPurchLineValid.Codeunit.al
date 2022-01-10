#pragma implicitwith disable
#pragma warning disable AA0072
codeunit 61002 "ALR Adv. Purch. - Line Valid."
{
    // This codeunit validates lines on purchase documents
    TableNo = "CDC Temp. Document Line";

    trigger OnRun()
    begin
        ALRLineValidation(Rec);

    end;

    local procedure ALRLineValidation(var TempDocumentLine: Record "CDC Temp. Document Line")
    var
        Document: Record "CDC Document";
        "Field": Record "CDC Template Field";
        DocumentComment: Record "CDC Document Comment";
        EmptyField: Record "CDC Template Field";
        PurchDocMgt: Codeunit "CDC Purch. Doc. - Management";
        CaptureMgt: Codeunit "CDC Capture Management";
        DCAppMgt: Codeunit "CDC Approval Management";
        //LineAccountNo: Code[250];
        LineDescription: Text[250];
        Quantity: Decimal;
        UnitCost: Decimal;
        LineAmount: Decimal;
        DiscAmount: Decimal;
        DiscPct: Decimal;
        LineAmount2: Decimal;
        OtherCharges: Decimal;
        UnitCharge: Decimal;
        CurrencyCode: Code[10];
        AmountRoundingPrecision: Decimal;
        CommentText: Text[1024];
        CommentType: Option Information,Warning,Error;
    begin
        if not Document.Get(TempDocumentLine."Document No.") then
            exit;

        Field.SetRange("Template No.", TempDocumentLine."Template No.");
        Field.SetRange(Type, Field.Type::Line);
        Field.SetRange(Required, true);
        if Field.FindSet() then
            repeat
                if StrLen(CaptureMgt.GetValueAsText(TempDocumentLine."Document No.", TempDocumentLine."Line No.", Field)) = 0 then
                    TempDocumentLine.Skip := true;
            until (Field.Next() = 0) or (TempDocumentLine.Skip);

        if TempDocumentLine.Skip then
            exit;

        //LineAccountNo := PurchDocMgt.GetLineAccountNo(Document, TempDocumentLine."Line No.");
        LineDescription := PurchDocMgt.GetLineDescription(Document, TempDocumentLine."Line No.");
        Quantity := PurchDocMgt.GetLineQuantity(Document, TempDocumentLine."Line No.");
        UnitCost := PurchDocMgt.GetLineUnitCost(Document, TempDocumentLine."Line No.");
        DiscPct := PurchDocMgt.GetLineDiscPct(Document, TempDocumentLine."Line No.");
        DiscAmount := PurchDocMgt.GetLineDiscAmount(Document, TempDocumentLine."Line No.");
        LineAmount := PurchDocMgt.GetLineAmount(Document, TempDocumentLine."Line No.");
        OtherCharges := PurchDocMgt.GetLineOtherCharges(Document, TempDocumentLine."Line No.");
        UnitCharge := PurchDocMgt.GetLineUnitCharge(Document, TempDocumentLine."Line No.");
        CurrencyCode := PurchDocMgt.GetCurrencyCode(Document);

        //ALR >>>
        //IF (LineAccountNo = '') AND (Quantity = 0) AND (UnitCost = 0) AND (LineAmount = 0) AND (DiscPct = 0) AND
        //  (DiscAmount = 0) AND (LineDescription = '')
        //THEN BEGIN
        //  Skip := TRUE;
        //  EXIT;
        //END;
        //ALR <<<

        Field.SetRange(Required);
        if Field.FindSet() then
            repeat
                if not CaptureMgt.IsValidValue(Field, TempDocumentLine."Document No.", TempDocumentLine."Line No.") then begin
                    // No need to write an error here as an error written in C6085580 - CDC Doc. - Field Validation
                    TempDocumentLine.OK := false;
                    exit;
                end;
            until Field.Next() = 0;

        if not DCAppMgt.GetAmountRoundingPrecision(CurrencyCode, AmountRoundingPrecision) then begin
            TempDocumentLine.OK := false;
            exit;
        end;

        LineAmount2 := Round(Quantity * (UnitCost + UnitCharge), AmountRoundingPrecision);
        LineAmount2 += Round(OtherCharges, AmountRoundingPrecision);

        if DiscAmount <> 0 then
            LineAmount2 := LineAmount2 - Round(DiscAmount, AmountRoundingPrecision)
        else
            if DiscPct <> 0 then begin
                // We are rounding the discount amount before we subtract it from LineAmount as this is how standard NAV behaves on an Invoice
                DiscAmount := Round(LineAmount2 * DiscPct / 100, AmountRoundingPrecision);
                LineAmount2 := LineAmount2 - DiscAmount;
            end;

        // We use AmountRoundingPrecision as any roundings should be equal to AmountRoundingPrecision. In this situation,
        // we want the used to be able to register the document.
        // When a document is registered with a rounding difference, the
        TempDocumentLine.OK := (Abs(LineAmount - LineAmount2) <= AmountRoundingPrecision);

        if TempDocumentLine."Create Comment" then
            if LineAmount <> LineAmount2 then begin
                if TempDocumentLine.OK then begin
                    CommentType := CommentType::Warning;
                    CommentText := WarningTxt;
                end else begin
                    CommentType := CommentType::Error;
                    CommentText := '%1';
                end;

                // LineAmount is Line Amount as captured/keyed in on the document line. We therefore want to show all decimals.
                if (DiscPct = 0) and (DiscAmount = 0) then
                    DocumentComment.Add(Document, EmptyField, TempDocumentLine."Line No.", DocumentComment.Area::Validation, CommentType,
                      StrSubstNo(CommentText, StrSubstNo(LineAmountDiffTxt, TempDocumentLine."Line No.", DCAppMgt.FormatAmountNoRounding(LineAmount, CurrencyCode),
                        DCAppMgt.FormatAmount(LineAmount2, CurrencyCode))))
                else
                    if DiscPct <> 0 then
                        DocumentComment.Add(Document, EmptyField, TempDocumentLine."Line No.", DocumentComment.Area::Validation, CommentType,
                          StrSubstNo(CommentText, StrSubstNo(LineAmountDiffCalcDiscAmtTxt, TempDocumentLine."Line No.",
                            DCAppMgt.FormatAmountNoRounding(LineAmount, CurrencyCode),
                            DCAppMgt.FormatAmount(LineAmount2, CurrencyCode), DiscPct, DCAppMgt.FormatAmount(DiscAmount, CurrencyCode))))
                    else
                        DocumentComment.Add(Document, EmptyField, TempDocumentLine."Line No.", DocumentComment.Area::Validation, CommentType,
                          StrSubstNo(CommentText, StrSubstNo(LineAmountDiffCapDiscAmtTxt, TempDocumentLine."Line No.",
                            DCAppMgt.FormatAmountNoRounding(LineAmount, CurrencyCode),
                            DCAppMgt.FormatAmount(LineAmount2, CurrencyCode), DCAppMgt.FormatAmount(DiscAmount, CurrencyCode))));
            end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CDC Purch. - Line Validation", 'OnBeforeLineValidation', '', true, true)]
    local procedure PurchLineValidation_OnBeforeLineValidation(var TempDocumentLine: Record "CDC Temp. Document Line"; Document: Record "CDC Document"; var Handled: Boolean)
    var
        CDCTemplate: record "CDC Template";
    begin
        if Handled then
            exit;

        if not CDCTemplate.Get(Document."Template No.") then
            exit;

        if CDCTemplate."ALR Line Validation Type" <> CDCTemplate."ALR Line Validation Type"::AdvancedLineRecognition then
            exit;

    end;

    var
        LineAmountDiffCalcDiscAmtTxt: Label 'Line Amount captured (%2) is different from Line Amount calculated (%3) using captured Discount % (%4) to calculate Discount Amount (%5) on line %1.', Comment = '%1 = line no. | %2 = captured line amount | %3 = calculated amount | %4 = captured discount in % | %5 = calculated discount';
        LineAmountDiffCapDiscAmtTxt: Label 'Line Amount captured (%2) is different from Line Amount calculated (%3) using captured Discount Amount (%4) on line %1.', Comment = '%1 = line no. | %2 = captured line amount | %3 = calculated amount | %4 = captured discount';
        LineAmountDiffTxt: Label 'Line Amount captured (%2) is different from Line Amount calculated (%3) on line %1.', Comment = '%1 = line no. | %2 = captured line amount | %3 = calculated line amount | %4 = captured discount | %5 = calculated discount';
        WarningTxt: Label 'WARNING: %1', Comment = '%1 is the warning message';
}

#pragma implicitwith restore

