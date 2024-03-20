tableextension 61001 "ALR Template" extends "CDC Template"
{
    fields
    {
        field(61000; "ALR Line Validation Type"; Option)
        {
            Caption = 'Line validation type';
            OptionMembers = TemplateCodeunit,AdvancedLineRecognition;
            OptionCaption = 'Default template codeunit,Advanced Line Recognition';
            DataClassification = CustomerContent;
        }
        field(61001; "Auto PO search"; Boolean)
        {
            Caption = 'Automatic PO search';
            DataClassification = CustomerContent;

            ObsoleteState = Pending;
            ObsoleteReason = 'Will be removed from ALR with next major release. Use dedicated PTE app going forward: https://github.com/document-capture/Automatic-PO-number-identification';
        }
        field(61002; "Auto PO search filter"; Text[200])
        {
            Caption = 'Automatic PO search filter';
            DataClassification = CustomerContent;
            ObsoleteState = Pending;
            ObsoleteReason = 'Will be removed from ALR with next major release. Use dedicated PTE app going forward: https://github.com/document-capture/Automatic-PO-number-identification';

            trigger OnLookup()
            var
                PurchasesPayablesSetup: Record "Purchases & Payables Setup";
                NoSeries: Record "No. Series";
                NoSeriesLine: Record "No. Series Line";
                Pos: Integer;
                OverWriteExistingPONumberFilterLbl: Label 'Do you want to overwrite the existing filter with a new automatically build filter?', Comment = 'Ask user to overwrite existingfilter string for automatic PO number filtering.', MaxLength = 999, Locked = false;
                NewPONumberFilterLbl: Label 'Do you want the system to automatically find a PO number filter?', Comment = 'Ask user to use automatic PO number filtering.', MaxLength = 999, Locked = false;
            begin
                if Rec."Auto PO search filter" <> '' then begin
                    if Confirm(OverWriteExistingPONumberFilterLbl, false) then
                        exit;
                end else
                    if not Confirm(NewPONumberFilterLbl, true) then
                        exit;

                // Create appropriate Filter string from Purchase Setup >>>
                PurchasesPayablesSetup.get();
                NoSeries.GET(PurchasesPayablesSetup."Order Nos.");
                NoSeriesLine.SETRANGE("Series Code", NoSeries.Code);
                NoSeriesLine.SETFILTER("Starting Date", '%1|<=%2', 0D, TODAY);
                NoSeriesLine.SETRANGE(Open, TRUE);
                if NoSeriesLine.FindFirst() then begin
                    Pos := 1;

                    while (Pos <= STRLEN(NoSeriesLine."Starting No.")) do begin
                        if NoSeriesLine."Starting No."[Pos] IN ['0' .. '9'] then
                            Rec."Auto PO search filter" += '?'
                        else
                            Rec."Auto PO search filter" += FORMAT(NoSeriesLine."Starting No."[Pos]);
                        Pos += 1;
                    end;
                end;
            end;
        }
    }
}
