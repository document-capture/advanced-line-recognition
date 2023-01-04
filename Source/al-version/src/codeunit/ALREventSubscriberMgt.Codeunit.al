codeunit 61005 "ALR Event Subscriber Mgt."
{
    var
        ALRAdvancedLineCapture: Codeunit "ALR Advanced Line Capture";

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CDC Capture Management", 'OnAfterApplyTranslationToWord', '', true, true)]
    local procedure CDCCaptureManagement_OnBeforeApplyTranslationToWord(var Field: Record "CDC Template Field"; var Word: Text[1024])
    begin
        ALRAdvancedLineCapture.ApplyAdvancedStringFunctions(Field, Word);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CDC Purch. - Full Capture", 'OnAfterFullCapture', '', true, true)]
    local procedure CDCPurchFullCapture_OnAfterFullCapture(Document: Record "CDC Document")
    begin
        ALRAdvancedLineCapture.FindAllPONumbersInDocument(Document);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CDC Capture Engine", 'OnBeforeRunLineCaptureCodeunit', '', true, true)]
    local procedure CDCCaptureEngine_OnBeforeRunLineCaptureCodeunit(Document: Record "CDC Document"; var Handled: Boolean)
    begin
        ALRAdvancedLineCapture.CleanupPrevValues(Document);
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CDC Capture Engine", 'OnBeforeAfterCapture', '', true, true)]
    local procedure CaptureEngine_OnBeforeAfterCapture(var Document: Record "CDC Document"; var IsHandled: Boolean)
    begin
        // Get source table values of header fields
        ALRAdvancedLineCapture.GetSourceFieldValues(Document, 0);

        // Get lookup field values of header fields
        ALRAdvancedLineCapture.GetLookupFieldValue(Document, 0);

        // Process advanced line capturing
        ALRAdvancedLineCapture.RunLineCapture(Document);
    end;
}
