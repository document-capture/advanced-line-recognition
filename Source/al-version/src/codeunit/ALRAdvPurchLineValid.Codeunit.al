codeunit 61002 "ALR Adv. Purch. - Line Valid."
{
    // This codeunit validates lines on purchase documents
    TableNo = "CDC Temp. Document Line";

    trigger OnRun()
    begin
        ALRLineValidation(Rec);

    end;

    local procedure ALRLineValidation(var CDCTempDocumentLine: Record "CDC Temp. Document Line")
    var
        CDCDocument: Record "CDC Document";
        CDCTemplateField: Record "CDC Template Field";
        CDCDocumentComment: Record "CDC Document Comment";
        EmptyCDCTemplateField: Record "CDC Template Field";
        CDCPurchDocManagement: Codeunit "CDC Purch. Doc. - Management";
        CDCCaptureManagement: Codeunit "CDC Capture Management";
        CDCApprovalManagement: Codeunit "CDC Approval Management";
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
        if not CDCDocument.Get(CDCTempDocumentLine."Document No.") then
            exit;

        CDCTemplateField.SetRange("Template No.", CDCTempDocumentLine."Template No.");
        CDCTemplateField.SetRange(Type, CDCTemplateField.Type::Line);
        CDCTemplateField.SetRange(Required, true);
        if CDCTemplateField.FindSet() then
            repeat
                if StrLen(CDCCaptureManagement.GetValueAsText(CDCTempDocumentLine."Document No.", CDCTempDocumentLine."Line No.", CDCTemplateField)) = 0 then
                    CDCTempDocumentLine.Skip := true;
            until (CDCTemplateField.Next() = 0) or (CDCTempDocumentLine.Skip);

        if CDCTempDocumentLine.Skip then
            exit;

        //LineAccountNo := PurchDocMgt.GetLineAccountNo(Document, CDCTempDocumentLine."Line No.");
        LineDescription := CDCPurchDocManagement.GetLineDescription(CDCDocument, CDCTempDocumentLine."Line No.");
        Quantity := CDCPurchDocManagement.GetLineQuantity(CDCDocument, CDCTempDocumentLine."Line No.");
        UnitCost := CDCPurchDocManagement.GetLineUnitCost(CDCDocument, CDCTempDocumentLine."Line No.");
        DiscPct := CDCPurchDocManagement.GetLineDiscPct(CDCDocument, CDCTempDocumentLine."Line No.");
        DiscAmount := CDCPurchDocManagement.GetLineDiscAmount(CDCDocument, CDCTempDocumentLine."Line No.");
        LineAmount := CDCPurchDocManagement.GetLineAmount(CDCDocument, CDCTempDocumentLine."Line No.");
        OtherCharges := CDCPurchDocManagement.GetLineOtherCharges(CDCDocument, CDCTempDocumentLine."Line No.");
        UnitCharge := CDCPurchDocManagement.GetLineUnitCharge(CDCDocument, CDCTempDocumentLine."Line No.");
        CurrencyCode := CDCPurchDocManagement.GetCurrencyCode(CDCDocument);

        //ALR >>>
        //IF (LineAccountNo = '') AND (Quantity = 0) AND (UnitCost = 0) AND (LineAmount = 0) AND (DiscPct = 0) AND
        //  (DiscAmount = 0) AND (LineDescription = '')
        //THEN BEGIN
        //  Skip := TRUE;
        //  EXIT;
        //END;
        //ALR <<<

        CDCTemplateField.SetRange(Required);
        if CDCTemplateField.FindSet() then
            repeat
                if not CDCCaptureManagement.IsValidValue(CDCTemplateField, CDCTempDocumentLine."Document No.", CDCTempDocumentLine."Line No.") then begin
                    // No need to write an error here as an error written in C6085580 - CDC Doc. - Field Validation
                    CDCTempDocumentLine.OK := false;
                    exit;
                end;
            until CDCTemplateField.Next() = 0;

        if not CDCApprovalManagement.GetAmountRoundingPrecision(CurrencyCode, AmountRoundingPrecision) then begin
            CDCTempDocumentLine.OK := false;
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
        CDCTempDocumentLine.OK := (Abs(LineAmount - LineAmount2) <= AmountRoundingPrecision);

        if CDCTempDocumentLine."Create Comment" then
            if LineAmount <> LineAmount2 then begin
                if CDCTempDocumentLine.OK then begin
                    CommentType := CommentType::Warning;
                    CommentText := WarningTxt;
                end else begin
                    CommentType := CommentType::Error;
                    CommentText := '%1';
                end;

                // LineAmount is Line Amount as captured/keyed in on the document line. We therefore want to show all decimals.
                if (DiscPct = 0) and (DiscAmount = 0) then
                    CDCDocumentComment.Add(CDCDocument, EmptyCDCTemplateField, CDCTempDocumentLine."Line No.", CDCDocumentComment.Area::Validation, CommentType,
                      StrSubstNo(CommentText, StrSubstNo(LineAmountDiffTxt, CDCTempDocumentLine."Line No.", CDCApprovalManagement.FormatAmountNoRounding(LineAmount, CurrencyCode),
                        CDCApprovalManagement.FormatAmount(LineAmount2, CurrencyCode))))
                else
                    if DiscPct <> 0 then
                        CDCDocumentComment.Add(CDCDocument, EmptyCDCTemplateField, CDCTempDocumentLine."Line No.", CDCDocumentComment.Area::Validation, CommentType,
                          StrSubstNo(CommentText, StrSubstNo(LineAmountDiffCalcDiscAmtTxt, CDCTempDocumentLine."Line No.",
                            CDCApprovalManagement.FormatAmountNoRounding(LineAmount, CurrencyCode),
                            CDCApprovalManagement.FormatAmount(LineAmount2, CurrencyCode), DiscPct, CDCApprovalManagement.FormatAmount(DiscAmount, CurrencyCode))))
                    else
                        CDCDocumentComment.Add(CDCDocument, EmptyCDCTemplateField, CDCTempDocumentLine."Line No.", CDCDocumentComment.Area::Validation, CommentType,
                          StrSubstNo(CommentText, StrSubstNo(LineAmountDiffCapDiscAmtTxt, CDCTempDocumentLine."Line No.",
                            CDCApprovalManagement.FormatAmountNoRounding(LineAmount, CurrencyCode),
                            CDCApprovalManagement.FormatAmount(LineAmount2, CurrencyCode), CDCApprovalManagement.FormatAmount(DiscAmount, CurrencyCode))));
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

        ALRLineValidation(TempDocumentLine);

        Handled := true;
    end;

    var
        LineAmountDiffCalcDiscAmtTxt: Label 'Line Amount captured (%2) is different from Line Amount calculated (%3) using captured Discount % (%4) to calculate Discount Amount (%5) on line %1.', Comment = '%1 = line no. | %2 = captured line amount | %3 = calculated amount | %4 = captured discount in % | %5 = calculated discount';
        LineAmountDiffCapDiscAmtTxt: Label 'Line Amount captured (%2) is different from Line Amount calculated (%3) using captured Discount Amount (%4) on line %1.', Comment = '%1 = line no. | %2 = captured line amount | %3 = calculated amount | %4 = captured discount';
        LineAmountDiffTxt: Label 'Line Amount captured (%2) is different from Line Amount calculated (%3) on line %1.', Comment = '%1 = line no. | %2 = captured line amount | %3 = calculated line amount | %4 = captured discount | %5 = calculated discount';
        WarningTxt: Label 'WARNING: %1', Comment = '%1 is the warning message';
}