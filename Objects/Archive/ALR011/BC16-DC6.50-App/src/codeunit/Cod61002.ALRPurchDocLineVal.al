codeunit 61002 "ALR Purch. Doc. - Line Val."
{
    // Original Object ID : 6085704
    // This codeunit validates lines on purchase documents

    TableNo = 6085596;

    trigger OnRun()
    var
        Document: Record "CDC Document";
        "Field": Record "CDC Template Field";
        DocumentComment: Record "CDC Document Comment";
        EmptyField: Record "CDC Template Field";
        PurchDocMgt: Codeunit "CDC Purch. Doc. - Management";
        CaptureMgt: Codeunit "CDC Capture Management";
        DCAppMgt: Codeunit "CDC Approval Management";
        Quantity: Decimal;
        UnitCost: Decimal;
        LineAmount: Decimal;
        DiscAmount: Decimal;
        DiscPct: Decimal;
        LineAmount2: Decimal;
        AmountRoundingPrecision: Decimal;
        OtherCharges: Decimal;
        UnitCharge: Decimal;
        LineDescription: Text[250];
        CommentText: Text[1024];
        LineAccountNo: Code[250];
        CurrencyCode: Code[10];
        CommentType: Option Information,Warning,Error;
        ALRTemplateField: Record "CDC Template Field";
    begin
        IF NOT Document.GET("Document No.") THEN
            EXIT;

        LineAccountNo := PurchDocMgt.GetLineAccountNo(Document, "Line No.");
        LineDescription := PurchDocMgt.GetLineDescription(Document, "Line No.");
        Quantity := PurchDocMgt.GetLineQuantity(Document, "Line No.");
        UnitCost := PurchDocMgt.GetLineUnitCost(Document, "Line No.");
        DiscPct := PurchDocMgt.GetLineDiscPct(Document, "Line No.");
        DiscAmount := PurchDocMgt.GetLineDiscAmount(Document, "Line No.");
        LineAmount := PurchDocMgt.GetLineAmount(Document, "Line No.");
        OtherCharges := PurchDocMgt.GetLineOtherCharges(Document, "Line No.");
        UnitCharge := PurchDocMgt.GetLineUnitCharge(Document, "Line No.");
        CurrencyCode := PurchDocMgt.GetCurrencyCode(Document);

        // ALR >>>
        //IF (LineAccountNo = '') AND (Quantity = 0) AND (UnitCost = 0) AND (LineAmount = 0) AND (DiscPct = 0) AND
        //  (DiscAmount = 0) AND (LineDescription = '')
        //THEN BEGIN
        //    Skip := TRUE;
        //   EXIT;
        //END;
        ALRTemplateField.SETRANGE("Template No.", Rec."Template No.");
        ALRTemplateField.SETRANGE(Type, ALRTemplateField.Type::Line);
        ALRTemplateField.SETRANGE(Required, TRUE);
        IF ALRTemplateField.FINDSET THEN
            REPEAT
                IF STRLEN(CaptureMgt.GetValueAsText("Document No.", "Line No.", ALRTemplateField)) = 0 THEN
                    Skip := TRUE;
            UNTIL ALRTemplateField.NEXT = 0;
        IF Skip THEN
            EXIT;
        // ALR <<<
        Field.SETRANGE("Template No.", "Template No.");
        Field.SETRANGE(Type, Field.Type::Line);
        IF Field.FINDSET THEN
            REPEAT
                IF NOT CaptureMgt.IsValidValue(Field, "Document No.", "Line No.") THEN BEGIN
                    // No need to write an error here as an error written in C6085580 - CDC Doc. - Field Validation
                    OK := FALSE;
                    EXIT;
                END;
            UNTIL Field.NEXT = 0;

        IF NOT DCAppMgt.GetAmountRoundingPrecision(CurrencyCode, AmountRoundingPrecision) THEN BEGIN
            OK := FALSE;
            EXIT;
        END;

        LineAmount2 := ROUND(Quantity * (UnitCost + UnitCharge), AmountRoundingPrecision);
        LineAmount2 += ROUND(OtherCharges, AmountRoundingPrecision);

        IF DiscAmount <> 0 THEN
            LineAmount2 := LineAmount2 - ROUND(DiscAmount, AmountRoundingPrecision)
        ELSE
            IF DiscPct <> 0 THEN BEGIN
                // We are rounding the discount amount before we subtract it from LineAmount as this is how standard NAV behaves on an Invoice
                DiscAmount := ROUND(LineAmount2 * DiscPct / 100, AmountRoundingPrecision);
                LineAmount2 := LineAmount2 - DiscAmount;
            END;

        // We use AmountRoundingPrecision as any roundings should be equal to AmountRoundingPrecision. In this situation,
        // we want the used to be able to register the document.
        // When a document is registered with a rounding difference, the
        OK := (ABS(LineAmount - LineAmount2) <= AmountRoundingPrecision);

        IF "Create Comment" THEN
            IF LineAmount <> LineAmount2 THEN BEGIN
                IF OK THEN BEGIN
                    CommentType := CommentType::Warning;
                    CommentText := WarningTxt;
                END ELSE BEGIN
                    CommentType := CommentType::Error;
                    CommentText := '%1';
                END;

                // LineAmount is Line Amount as captured/keyed in on the document line. We therefore want to show all decimals.
                IF (DiscPct = 0) AND (DiscAmount = 0) THEN
                    DocumentComment.Add(Document, EmptyField, "Line No.", DocumentComment.Area::Validation, CommentType,
                      STRSUBSTNO(CommentText, STRSUBSTNO(LineAmountDiffTxt, "Line No.", DCAppMgt.FormatAmountNoRounding(LineAmount, CurrencyCode),
                        DCAppMgt.FormatAmount(LineAmount2, CurrencyCode))))
                ELSE
                    IF DiscPct <> 0 THEN
                        DocumentComment.Add(Document, EmptyField, "Line No.", DocumentComment.Area::Validation, CommentType,
                          STRSUBSTNO(CommentText, STRSUBSTNO(LineAmountDiffCalcDiscAmtTxt, "Line No.",
                            DCAppMgt.FormatAmountNoRounding(LineAmount, CurrencyCode),
                            DCAppMgt.FormatAmount(LineAmount2, CurrencyCode), DiscPct, DCAppMgt.FormatAmount(DiscAmount, CurrencyCode))))
                    ELSE
                        DocumentComment.Add(Document, EmptyField, "Line No.", DocumentComment.Area::Validation, CommentType,
                          STRSUBSTNO(CommentText, STRSUBSTNO(LineAmountDiffCapDiscAmtTxt, "Line No.",
                            DCAppMgt.FormatAmountNoRounding(LineAmount, CurrencyCode),
                            DCAppMgt.FormatAmount(LineAmount2, CurrencyCode), DCAppMgt.FormatAmount(DiscAmount, CurrencyCode))));
            END;
    end;

    var
        LineAmountDiffCalcDiscAmtTxt: Label 'Line Amount captured (%2) is different from Line Amount calculated (%3) using captured Discount % (%4) to calculate Discount Amount (%5) on line %1.';
        LineAmountDiffCapDiscAmtTxt: Label 'Line Amount captured (%2) is different from Line Amount calculated (%3) using captured Discount Amount (%4) on line %1.';
        LineAmountDiffTxt: Label 'Line Amount captured (%2) is different from Line Amount calculated (%3) on line %1.';
        WarningTxt: Label 'WARNING: %1';
}

