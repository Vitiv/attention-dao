// import { test; suite } "mo:test/async";
import Debug "mo:base/Debug";
import PH "../src/dao-small-backend/ProposalHandler";
import CT "../src/dao-small-backend/CommonTypes";

actor {
    type ProposalContent = CT.ProposalContent;
    type Result = CT.CommonResult;

    public func runTests() : async () {
        Debug.print("Запуск тестов для модуля обработки предложений...");

        // await testRejectProposal();
        await testValidateProposal();

        Debug.print("Все тесты завершены!");
    };

    // func testRejectProposal() : async () {
    //     Debug.print("Тест: отклонение предложения");

    //     let testProposal : DAO.Proposal<ProposalContent> = {
    //         id = 1;
    //         proposerId = Principal.fromText("aaaaa-aa");
    //         timeStart = Time.now();
    //         timeEnd = Time.now() + 1000000000;
    //         endTimerId = null;
    //         content = {
    //             description = "Тестовое предложение";
    //             action = "Тестовое действие";
    //         };
    //         votes = [];
    //         statusLog = [];
    //     };

    //     let result = await* PH.rejectProposal(testProposal);
    //     switch (result) {
    //         case (#ok) Debug.print("Предложение успешно отклонено");
    //         case (#err(e)) Debug.print("Ошибка при отклонении предложения: " # e);
    //     };
    // };

    func testValidateProposal() : async () {
        Debug.print("Тест: валидация предложения");

        let validContent : ProposalContent = #other{
            description = "Это валидное тестовое предложение длиной более 10 символов";
            action = "Валидное действие";
        };

        let invalidContent : ProposalContent = #other{
            description = "Короткое";
            action = "Кратко";
        };

        let validResult = await* PH.validateProposal(validContent);
        switch (validResult) {
            case (#ok) Debug.print("Валидное предложение успешно прошло проверку");
            case (#err(_)) Debug.print("Ошибка: валидное предложение не прошло проверку");
        };

        let invalidResult = await* PH.validateProposal(invalidContent);
        switch (invalidResult) {
            case (#ok) Debug.print("Ошибка: невалидное предложение прошло проверку");
            case (#err(_)) Debug.print("Невалидное предложение корректно не прошло проверку");
        };
    };
};
