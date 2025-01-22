#include <unistd.h>
#include <io.h>
#include <sd_card.h>
#include <fs.h>

#include <stdlib.h>
#include <string.h>
#include <stdio.h>

void prints(const char *s, const char *s2)
{
    print(s);
    print(s2);
    print("\r\n");
}

void printv(const char *s, unsigned int v)
{
    print(s);
    char r[32];
    itoa(v, r, 10);
    print(r);
    print("\r\n");
}

bool print_dir(fs_context_t *fs_ctx)
{
    uint16_t nb_files = fs_get_nb_files(fs_ctx);
    printv("Nb files: ", nb_files);

    for (uint16_t i = 0; i < nb_files; ++i) {
        fs_file_info_t file_info;
        if (!fs_get_file_info(fs_ctx, i, &file_info)) {
            print("Unable to get file info\r\n");
            return false;
        }
        printv("File #", i);
        prints("  Name: ", file_info.name);
        printv("  Size: ", file_info.size);
        printv("    Nb blocks: ", (file_info.size + SD_BLOCK_LEN - 1) / SD_BLOCK_LEN);
        printv("  First block table index: ", file_info.first_block_table_index);
    }

    return true;
}

void dump_fat(fs_context_t *ctx)
{
    print("**** FAT DUMP ****\r\n");
    print_dir(ctx);
    for (size_t i = 0; i < FS_MAX_NB_BLOCKS; ++i) {
        if (ctx->fat.blocks[i] == 0xFFFF) {
            print ("-");
        } else {
            char b[16];
            itoa(ctx->fat.blocks[i], b, 10);
            print(b);
        }
        print(" ");
    }
    print("\r\n");
    print("**** END OF FAT DUMP ****\r\n");
}

bool low_level_tests(sd_context_t *sd_ctx)
{
    print("\r\n--- Low Level Tests ---\r\n");

    fs_context_t fs_ctx;
    if (!fs_init(sd_ctx, &fs_ctx)) {
        print("Unable to initialize the FS\r\n");
        return false;
    }
    uint16_t nb_files;
    nb_files = fs_get_nb_files(&fs_ctx);

    printv("Nb files: ", nb_files);

    if (nb_files > 0) {
        print("No file expected\r\n");
        return false;
    }

    char *s1 = "test1 file content";
    if (!fs_write(&fs_ctx, "test1", s1, 0, strlen(s1) + 1)) {
        print("FS write failed\r\n");
        return false;
    }

    char *s2 = "test2 file content with a long string";
    if (!fs_write(&fs_ctx, "test2", s2, 0, strlen(s2) + 1)) {
        print("FS write failed\r\n");
        return false;
    }

    if (!print_dir(&fs_ctx)) {
        print("Dir failed\r\n");
        return false;
    }

    nb_files = fs_get_nb_files(&fs_ctx);
    if (nb_files != 2) {
        print("Two files expected\r\n");
        return false;
    }

    char buf[128];
    if (!fs_read(&fs_ctx, "test1", buf, 0, sizeof(buf), NULL)) {
        print("Unable to read file\r\n");
        return false;
    }

    print("File content: ");
    print(buf);
    print("\r\n");

    if (strcmp(buf, s1) != 0) {
        print("Invalid file content\r\n");
        return false;
    }

    if (!fs_delete(&fs_ctx, "test1")) {
        print("Unable to delete file\r\n");
        return false;
    }

    if (!print_dir(&fs_ctx)) {
        print("Dir failed\r\n");
        return false;
    }

    nb_files = fs_get_nb_files(&fs_ctx);
    if (nb_files != 1) {
        print("One file expected\r\n");
        return false;
    }

    fs_file_info_t file_info;
    if (!fs_get_file_info(&fs_ctx, 0, &file_info)) {
        print("Get file info failed\r\n");
        return false;
    }

    if (strcmp(file_info.name, "test2") != 0) {
        print("Invalid remaining file name\r\n");
        return false;
    }

    if (!fs_read(&fs_ctx, "test2", buf, 0, sizeof(buf), NULL)) {
        print("Unable to read file\r\n");
        return false;
    }

    print("File content: ");
    print(buf);
    print("\r\n");

    if (strcmp(buf, s2) != 0) {
        print("Invalid file content\r\n");
        return false;
    }

    if (!fs_delete(&fs_ctx, "test2")) {
        print("Unable to delete file\r\n");
        return false;
    }

    //
    // Large file (more than one block) test
    //

    uint32_t *large_buf = (uint32_t *)malloc(1024*sizeof(uint32_t));

    if (!large_buf) {
        print("Unable to allocate large buffer\r\n");
        return false;
    }

    for (uint32_t i = 0; i < 1024; ++i)
        large_buf[i] = i;
    
    print("Write large file...\r\n");
    if (!fs_write(&fs_ctx, "test3", (uint8_t *)large_buf, 0, 1024*sizeof(uint32_t))) {
        print("FS write failed\r\n");
        return false;
    }

    char *s4 = "test4 file content";
    if (!fs_write(&fs_ctx, "test4", s1, 0, strlen(s1) + 1)) {
        print("FS write failed\r\n");
        return false;
    }

    if (!fs_delete(&fs_ctx, "test4")) {
        print("Unable to delete file\r\n");
        return false;
    }

    memset(large_buf, 0, 1024*sizeof(uint32_t));

    print("Read large file...\r\n");
    if (!fs_read(&fs_ctx, "test3", (uint8_t *)large_buf, 0, 1024*sizeof(uint32_t), NULL)) {
        free(large_buf);
        print("FS read failed\r\n");
        return false;
    }

    for (uint32_t i = 0; i < 1024; ++i)
        if (large_buf[i] != i) {
            free(large_buf);
            printv("Mismatch detected at index: ", i);
            return false;
        }

    free(large_buf);
    return true;
}

bool stdio_tests()
{
    print("\r\n--- Standard IO Tests ---\r\n");


    FILE *fp = fopen("test4", "w");
    if (!fp) {
        print("Unable to open file for writing\r\n");
        return false;
    }

    uint32_t *large_buf = (uint32_t *)malloc(5000*sizeof(uint32_t));

    if (!large_buf) {
        print("Unable to allocate large buffer\r\n");
        return false;
    }
    
    for (uint32_t i = 0; i < 5000; ++i)
        large_buf[i] = i;

    size_t nb_elements = fwrite(large_buf, sizeof(uint32_t), 5000, fp);
    fclose(fp);

    printv("Nb written elements: ", nb_elements);

    if (nb_elements != 5000) {
        print("Unable to write all the elements\r\n");
        perror("The following error occurred");
        free(large_buf);
        return false;
    }

    FILE *fp2 = fopen("test5", "w");
    if (!fp2) {
        print("Unable to open file for writing\r\n");
        return false;
    }
    
    for (uint32_t i = 0; i < 5000; ++i)
        large_buf[i] = i + 5000;

    nb_elements = fwrite(large_buf, sizeof(uint32_t), 5000, fp2);
    fclose(fp2);

    printv("Nb written elements: ", nb_elements);

    if (nb_elements != 5000) {
        print("Unable to write all the elements\r\n");
        perror("The following error occurred");
        free(large_buf);
        return false;
    }

    fp = fopen("test4", "r");
    if (!fp) {
        print("Unable to open file for reading\r\n");
        free(large_buf);
        return false;
    }

    memset(large_buf, 0, 5000*sizeof(uint32_t));

    nb_elements = fread(large_buf, sizeof(uint32_t), 5000, fp);
    fclose(fp);
    printv("Nb read elements: ", nb_elements);

    if (nb_elements != 5000) {
        print("Unable to read all the elements\r\n");
        perror("The following error occurred");
        free(large_buf);
        return false;
    }

    for (uint32_t i = 0; i < 5000; ++i)
        if (large_buf[i] != i) {
            free(large_buf);
            printv("Mismatch detected at index: ", i);
            printv("Expected: ", i);
            printv("Received: ", large_buf[i]);
            free(large_buf);
            return false;
        }    

    free(large_buf);

    return true;
}

void main(void)
{
    print("************** FILE SYSTEM TEST **************\r\n");
    sd_context_t sd_ctx;
    if (!sd_init(&sd_ctx)) {
        print("Unable to initialize SD card\r\n");
        for(;;);
    }
    print("Formatting...\r\n");
    if (!fs_format(&sd_ctx, true)) {
        print("Unable to format SD card\r\n");
        for(;;);
    }

    if (!low_level_tests(&sd_ctx)) {
        printf("Low level tests failed\r\n");
        for(;;);
    }

    if (!stdio_tests()) {
        printf("Standard IO tests failed\r\n");
        fs_context_t fs_ctx;
        if (fs_init(&sd_ctx, &fs_ctx))
            dump_fat(&fs_ctx);
        for(;;);
    }

    print("Success!\r\n");
    fs_context_t fs_ctx;
    if (fs_init(&sd_ctx, &fs_ctx))
        dump_fat(&fs_ctx);
    for(;;);
}
