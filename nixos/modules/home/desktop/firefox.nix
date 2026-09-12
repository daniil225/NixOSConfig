{ ... }:
{
  programs.firefox = {
    enable = true;

    profiles = {
      default = {
        id = 0;
        name = "default";
        isDefault = true;

        bookmarks = [
          {
            name = "general";
            bookmarks = [
              {
                name = "GitHub";
                url = "https://github.com/daniil225";
              }
              {
                name = "Вот это английский";
                tags = [
                  "Education"
                ];
                url = "https://dop.votetoang.com/cabinet.php";
              }
              {
                name = "Konstantin Vladimirov - exclusive content on Boosty";
                url = "https://boosty.to/cpp_lects_rus";
              }
            ];
          }
          {
            name = "Mail";
            bookmarks = [
              {
                tags = [
                  "mail"
                ];
                name = "Яндекс.Почта";
                url = "https://mail.yandex.ru/lite/inbox";
              }
            ];
          }
          {
            name = "ITMO";
            bookmarks = [
              {
                tags = [
                  "ITMO"
                  "Education"
                ];
                name = "Yandex Messenger";
                url = "https://yandex.ru/chat#/";
              }
              {
                tags = [
                  "ITMO"
                  "Education"
                ];
                name = "Цифровые сервисы";
                url = "https://student.itmo.ru/ru/services/digital";
              }
              {
                tags = [
                  "ITMO"
                  "Education"
                ];
                name = "Яндекс Практикум";
                url = "https://practicum.yandex.ru/profile/higher-front-back-dev/";
              }
            ];
          }
          {
            name = "YADRO";
            bookmarks = [ ];
          }
        ];
      };
    };
  };
}
