codeunit 61005 "ALR Event Subscriber Mgt."
{
    var
        ALRCapture: Codeunit "ALR Advanced Line Capture";

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CDC Capture Management", 'OnAfterApplyTranslationToWord', '', true, true)]
    local procedure CDCCaptureManagement_OnBeforeApplyTranslationToWord(var Field: Record "CDC Template Field"; var Word: Text[1024])
    begin
        ALRCapture.ApplyAdvancedStringFunctions(Field, Word);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CDC Purch. - Full Capture", 'OnAfterFullCapture', '', true, true)]
    local procedure CDCPurchFullCapture_OnAfterFullCapture(Document: Record "CDC Document")
    begin
        ALRCapture.FindAllPONumbersInDocument(Document);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CDC Capture Engine", 'OnBeforeRunLineCaptureCodeunit', '', true, true)]
    local procedure CDCCaptureEngine_OnBeforeRunLineCaptureCodeunit(Document: Record "CDC Document"; var Handled: Boolean)
    var
        TempDocLine: Record "CDC Temp. Document Line" temporary;
        CDCTemplateField: Record "CDC Template Field";
        TempSortedDocumentField: Record "CDC Temp. Document Field" temporary;
    begin
        ALRCapture.RunLineCapture(Document, Handled);
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CDC Capture Engine", 'OnBeforeAfterCapture', '', true, true)]
    local procedure CaptureEngine_OnBeforeAfterCapture(var Document: Record "CDC Document"; var IsHandled: Boolean)
    begin
        ALRCapture.GetSourceFieldValues(Document, IsHandled)
    end;
}
