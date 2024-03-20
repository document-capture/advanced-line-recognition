codeunit 61003 "ALR Single Instance Mgt."
{
    SingleInstance = true;

    trigger OnRun()
    begin
    end;

    var
        CurrDocumentNo: Code[20];
        LineRegionFromPage: Integer;
        LineRegionFromPos: Integer;
        LineRegionToPage: Integer;
        LineRegionToPos: Integer;
        StringFilterLbl: Label '%1..%2', Comment = '%1 start filter | %2 end filter', Locked = true;

    procedure SetLineRegion(DocumentNo: Code[20]; FromPage: Integer; FromPos: Integer; ToPage: Integer; ToPos: Integer)
    begin
        CurrDocumentNo := DocumentNo;
        LineRegionFromPage := FromPage;
        LineRegionFromPos := FromPos;
        LineRegionToPage := ToPage;
        LineRegionToPos := ToPos;
    end;

    [EventSubscriber(ObjectType::Codeunit, 6085575, 'OnBeforeBufferWords', '', false, false)]
    local procedure OnBeforeBufferWordsSubscriber(DocumentNo: Code[20]; PageNo: Integer; var Words: Record "CDC Document Word"; var GlobalWords: Record "CDC Document Word"; var Handled: Boolean)
    var
        DocumentPage: Record "CDC Document Page";
    begin
        if (CurrDocumentNo = DocumentNo) and ((LineRegionFromPage > 0) or (LineRegionToPage > 0)) then begin
            Words.SetRange("Document No.", DocumentNo);
            DocumentPage.SetRange("Document No.", DocumentNo);
            DocumentPage.SetRange("Page No.", LineRegionFromPage, LineRegionToPage);
            if DocumentPage.FindSet() then begin
                Handled := true;
                repeat
                    if LineRegionToPos = 0 then
                        Words.SetFilter(Top, StrSubstNo(StringFilterLbl, LineRegionFromPos, DocumentPage."Bottom Word Pos."))
                    else
                        Words.SetFilter(Top, DelChr(StrSubstNo(StringFilterLbl, LineRegionFromPos, LineRegionToPos), '=', ' '));

                    if Words.FindSet(false) then
                        repeat
                            GlobalWords := Words;
                            GlobalWords.Insert();
                        until Words.Next() = 0
                until DocumentPage.Next() = 0;
            end;
            SetLineRegion('', 0, 0, 0, 0);
        end;
    end;
}

