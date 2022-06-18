#include <unistd.h>
#include <io.h>
#include <sd_card.h>
#include <fs.h>

#include <stdlib.h>
#include <string.h>

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
        char b[16];
        itoa(ctx->fat.blocks[i], b, 10);
        print(b);
        print(" ");
    }
    print("\r\n");
    print("**** END OF FAT DUMP ****\r\n");
}

void main(void)
{
    print("************** FILE SYSTEM TEST ****************\r\n");
    sd_context_t sd_ctx;
    if (!sd_init(&sd_ctx)) {
        print("Unable to initialize SD card\r\n");
        return;
    }
    print("Formatting...\r\n");
    if (!fs_format(&sd_ctx)) {
        print("Unable to format SD card\r\n");
        return;
    }

    fs_context_t fs_ctx;
    if (!fs_init(&sd_ctx, &fs_ctx)) {
        print("Unable to initialize the FS\r\n");
        return;
    }
    uint16_t nb_files;
    nb_files = fs_get_nb_files(&fs_ctx);

    printv("Nb files: ", nb_files);

    if (nb_files > 0) {
        print("No file expected\r\n");
        return;
    }

    char *s1 = "test1 file content";
    if (!fs_write(&fs_ctx, "test1", s1, strlen(s1) + 1)) {
        print("FS write failed\r\n");
        return;
    }

    char *s2 = "test2 file content with a long string";
    if (!fs_write(&fs_ctx, "test2", s2, strlen(s2) + 1)) {
        print("FS write failed\r\n");
        return;
    }

    if (!print_dir(&fs_ctx)) {
        print("Dir failed\r\n");
        return;
    }

    nb_files = fs_get_nb_files(&fs_ctx);
    if (nb_files != 2) {
        print("Two files expected\r\n");
        return;
    }

    char buf[128];
    if (!fs_read(&fs_ctx, "test1", buf, sizeof(buf))) {
        print("Unable to read file\r\n");
        return;
    }

    print("File content: ");
    print(buf);
    print("\r\n");

    if (strcmp(buf, s1) != 0) {
        print("Invalid file content\r\n");
        return;
    }

    if (!fs_delete(&fs_ctx, "test1")) {
        print("Unable to delete file\r\n");
        return;
    }

    if (!print_dir(&fs_ctx)) {
        print("Dir failed\r\n");
        return;
    }

    nb_files = fs_get_nb_files(&fs_ctx);
    if (nb_files != 1) {
        print("One file expected\r\n");
        return;
    }

    fs_file_info_t file_info;
    if (!fs_get_file_info(&fs_ctx, 0, &file_info)) {
        print("Get file info failed\r\n");
        return;
    }

    if (strcmp(file_info.name, "test2") != 0) {
        print("Invalid remaining file name\r\n");
        return;
    }

    if (!fs_read(&fs_ctx, "test2", buf, sizeof(buf))) {
        print("Unable to read file\r\n");
        return;
    }

    print("File content: ");
    print(buf);
    print("\r\n");

    if (strcmp(buf, s2) != 0) {
        print("Invalid file content\r\n");
        return;
    }    

    //
    // Large file (more than one block) test
    //

    uint32_t *large_buf = (uint32_t *)malloc(1024*sizeof(uint32_t));

    if (!large_buf) {
        print("Unable to allocate large buffer\r\n");
        return;
    }

    for (uint32_t i = 0; i < 1024; ++i)
        large_buf[i] = i;
    
    print("Write large file...\r\n");
    if (!fs_write(&fs_ctx, "test3", (uint8_t *)large_buf, 1024*sizeof(uint32_t))) {
        print("FS write failed\r\n");
        return;
    }

    dump_fat(&fs_ctx);

    memset(large_buf, 0, 1024*sizeof(uint32_t));

    print("Read large file...\r\n");
    if (!fs_read(&fs_ctx, "test3", (uint8_t *)large_buf, 1024*sizeof(uint32_t))) {
        free(large_buf);
        print("FS read failed\r\n");
        return;
    }

    for (uint32_t i = 0; i < 1024; ++i)
        if (large_buf[i] != i) {
            free(large_buf);
            printv("Mismatch detected at index: ", i);
            return;
        }

    free(large_buf);
    print("Success!\r\n");
}
