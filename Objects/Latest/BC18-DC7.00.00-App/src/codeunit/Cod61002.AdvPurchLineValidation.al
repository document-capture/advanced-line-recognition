#pragma implicitwith disable
codeunit 61002 "Adv. Purch. - Line Validation"
{
    // This codeunit validates lines on purchase documents

    TableNo = "CDC Temp. Document Line";

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
        if not Document.Get(Rec."Document No.") then
            exit;

        LineAccountNo := PurchDocMgt.GetLineAccountNo(Document, Rec."Line No.");
        LineDescription := PurchDocMgt.GetLineDescription(Document, Rec."Line No.");
        Quantity := PurchDocMgt.GetLineQuantity(Document, Rec."Line No.");
        UnitCost := PurchDocMgt.GetLineUnitCost(Document, Rec."Line No.");
        DiscPct := PurchDocMgt.GetLineDiscPct(Document, Rec."Line No.");
        DiscAmount := PurchDocMgt.GetLineDiscAmount(Document, Rec."Line No.");
        LineAmount := PurchDocMgt.GetLineAmount(Document, Rec."Line No.");
        OtherCharges := PurchDocMgt.GetLineOtherCharges(Document, Rec."Line No.");
        UnitCharge := PurchDocMgt.GetLineUnitCharge(Document, Rec."Line No.");
        CurrencyCode := PurchDocMgt.GetCurrencyCode(Document);

        //ALR >>>
        //IF (LineAccountNo = '') AND (Quantity = 0) AND (UnitCost = 0) AND (LineAmount = 0) AND (DiscPct = 0) AND
        //  (DiscAmount = 0) AND (LineDescription = '')
        //THEN BEGIN
        //  Skip := TRUE;
        //  EXIT;
        //END;
        ALRTemplateField.SetRange("Template No.", Rec."Template No.");
        ALRTemplateField.SetRange(Type, ALRTemplateField.Type::Line);
        ALRTemplateField.SetRange(Required, true);
        if ALRTemplateField.FindSet then
            repeat
                if StrLen(CaptureMgt.GetValueAsText(Rec."Document No.", Rec."Line No.", ALRTemplateField)) = 0 then
                    Rec.Skip := true;
            until ALRTemplateField.Next = 0;
        if Rec.Skip then
            exit;
        //ALR <<<

        Field.SetRange("Template No.", Rec."Template No.");
        Field.SetRange(Type, Field.Type::Line);
        if Field.FindSet then
            repeat
                if not CaptureMgt.IsValidValue(Field, Rec."Document No.", Rec."Line No.") then begin
                    // No need to write an error here as an error written in C6085580 - CDC Doc. - Field Validation
                    Rec.OK := false;
                    exit;
                end;
            until Field.Next = 0;

        if not DCAppMgt.GetAmountRoundingPrecision(CurrencyCode, AmountRoundingPrecision) then begin
            Rec.OK := false;
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
        Rec.OK := (Abs(LineAmount - LineAmount2) <= AmountRoundingPrecision);

        if Rec."Create Comment" then
            if LineAmount <> LineAmount2 then begin
                if Rec.OK then begin
                    CommentType := CommentType::Warning;
                    CommentText := WarningTxt;
                end else begin
                    CommentType := CommentType::Error;
                    CommentText := '%1';
                end;

                // LineAmount is Line Amount as captured/keyed in on the document line. We therefore want to show all decimals.
                if (DiscPct = 0) and (DiscAmount = 0) then
                    DocumentComment.Add(Document, EmptyField, Rec."Line No.", DocumentComment.Area::Validation, CommentType,
                      StrSubstNo(CommentText, StrSubstNo(LineAmountDiffTxt, Rec."Line No.", DCAppMgt.FormatAmountNoRounding(LineAmount, CurrencyCode),
                        DCAppMgt.FormatAmount(LineAmount2, CurrencyCode))))
                else
                    if DiscPct <> 0 then
                        DocumentComment.Add(Document, EmptyField, Rec."Line No.", DocumentComment.Area::Validation, CommentType,
                          StrSubstNo(CommentText, StrSubstNo(LineAmountDiffCalcDiscAmtTxt, Rec."Line No.",
                            DCAppMgt.FormatAmountNoRounding(LineAmount, CurrencyCode),
                            DCAppMgt.FormatAmount(LineAmount2, CurrencyCode), DiscPct, DCAppMgt.FormatAmount(DiscAmount, CurrencyCode))))
                    else
                        DocumentComment.Add(Document, EmptyField, Rec."Line No.", DocumentComment.Area::Validation, CommentType,
                          StrSubstNo(CommentText, StrSubstNo(LineAmountDiffCapDiscAmtTxt, Rec."Line No.",
                            DCAppMgt.FormatAmountNoRounding(LineAmount, CurrencyCode),
                            DCAppMgt.FormatAmount(LineAmount2, CurrencyCode), DCAppMgt.FormatAmount(DiscAmount, CurrencyCode))));
            end;
    end;

    var
        LineAmountDiffCalcDiscAmtTxt: Label 'Line Amount captured (%2) is different from Line Amount calculated (%3) using captured Discount % (%4) to calculate Discount Amount (%5) on line %1.';
        LineAmountDiffCapDiscAmtTxt: Label 'Line Amount captured (%2) is different from Line Amount calculated (%3) using captured Discount Amount (%4) on line %1.';
        LineAmountDiffTxt: Label 'Line Amount captured (%2) is different from Line Amount calculated (%3) on line %1.';
        WarningTxt: Label 'WARNING: %1';
}

#pragma implicitwith restore

