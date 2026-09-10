// AIDL: define os metodos que rodam no processo privilegiado do Shizuku.
package com.example.chunktool;

interface IShizukuUserService {
    // Retorna os nomes das pastas de mundo encontradas, separados por quebra de linha.
    String listWorlds();

    // Copia um mundo da pasta protegida para uma pasta de staging que o app já pode acessar.
    boolean copyWorldToStaging(String worldFolderName, String stagingPath);

    // Copia de volta o mundo (já editado) do staging para a pasta protegida original.
    boolean copyStagingBackToWorld(String worldFolderName, String stagingPath);

    // Encerra o processo do servico quando terminamos de usar.
    void destroy();
}
