permissionset 61000 "ALR Permissions All"
{
    Access = Internal;
    Assignable = true;
    Caption = 'All permissions', Locked = true;

    Permissions =
         codeunit "ALR Adv. Purch. - Line Valid." = X,
         codeunit "ALR Adv. Recognition Mgt." = X,
         codeunit "ALR Advanced Line Capture" = X,
         codeunit "ALR Event Subscriber Mgt." = X,
         codeunit "ALR Single Instance Mgt." = X,
         codeunit "ALR Template Helper" = X,
         codeunit "ALR Upgrade Management" = X,
         page "ALR Table Filter Field List" = X;
}