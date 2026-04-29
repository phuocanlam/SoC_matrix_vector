#include <sys/types.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <dirent.h>
#include <errno.h>

typedef uint32_t U32;
typedef uint64_t U64;

/* =========================
 * Physical address layout
 * ========================= */
#define DMA_BASE_PHYS      0x00000000FD500000ULL
#define DMA_MMAP_SIZE      0x0000000000010000ULL   /* 64KB */

#define REG_BASE_PHYS      0x00000000A0000000ULL
#define REG_MMAP_SIZE      0x0000000010000000ULL   /* 4GB */

#define LMM_BASE_PHYS      0x00000000A4000000ULL

#define DDR_BASE_PHYS      0x0000000800000000ULL
#define DDR_MMAP_SIZE      0x0000000080000000ULL   /* 2GB */

/* =========================
 * Optional local memory offsets
 * ========================= */
#define PADDING_BASE       0x00100000
#define ROW0_BASE_PHYS     (0x00000000 + PADDING_BASE)
#define ROW1_BASE_PHYS     (0x00008000 + PADDING_BASE)
#define ROW2_BASE_PHYS     (0x00010000 + PADDING_BASE)
#define ROW3_BASE_PHYS     (0x00018000 + PADDING_BASE)

/* =========================
 * Host-side state
 * ========================= */
struct my_ip_handle {
    volatile U64 dma_ctrl;   /* mapped DMA register base */
    volatile U64 reg_ctrl;   /* reserved */

    U64 status : 4;

    U64 rw;
    U64 ddraddr;
    U64 lmmaddr;
    U64 dmalen;
};

static struct my_ip_handle my_ip;

/* =========================
 * DMA register map
 * ========================= */
struct dma_ctrl {
    U32 ZDMA_ERR_CTRL;            U32 rsv0[63];
    U32 ZDMA_CH_ISR;
    U32 ZDMA_CH_IMR;
    U32 ZDMA_CH_IEN;
    U32 ZDMA_CH_IDS;
    U32 ZDMA_CH_CTRL0;
    U32 ZDMA_CH_CTRL1;
    U32 ZDMA_CH_FCI;
    U32 ZDMA_CH_STATUS;

    U32 ZDMA_CH_DATA_ATTR;
    U32 ZDMA_CH_DSCR_ATTR;
    U32 ZDMA_CH_SRC_DSCR_WORD0;
    U32 ZDMA_CH_SRC_DSCR_WORD1;
    U32 ZDMA_CH_SRC_DSCR_WORD2;
    U32 ZDMA_CH_SRC_DSCR_WORD3;
    U32 ZDMA_CH_DST_DSCR_WORD0;
    U32 ZDMA_CH_DST_DSCR_WORD1;
    U32 ZDMA_CH_DST_DSCR_WORD2;
    U32 ZDMA_CH_DST_DSCR_WORD3;

    U32 ZDMA_CH_WR_ONLY_WORD0;
    U32 ZDMA_CH_WR_ONLY_WORD1;
    U32 ZDMA_CH_WR_ONLY_WORD2;
    U32 ZDMA_CH_WR_ONLY_WORD3;
    U32 ZDMA_CH_SRC_START_LSB;
    U32 ZDMA_CH_SRC_START_MSB;
    U32 ZDMA_CH_DST_START_LSB;
    U32 ZDMA_CH_DST_START_MSB;

    U32 rsv1[9];
    U32 ZDMA_CH_RATE_CTRL;
    U32 ZDMA_CH_IRQ_SRC_ACCT;
    U32 ZDMA_CH_IRQ_DST_ACCT;
    U32 rsv2[26];
    U32 ZDMA_CH_CTRL2;
};

/* =========================
 * Global driver info
 * ========================= */
struct MY_IP_info_t {
    U64 dma_phys;
    U64 dma_mmap;

    U64 reg_phys;
    U32 *pio_mmap;

    U64 lmm_phys;
    U64 lmm_mmap;

    U64 ddr_phys;
    U64 ddr_mmap;

    int driver_use_1;
    int driver_use_2;

    /* Optional simulation fields */
    FILE *CTX_RC_File;
    FILE *CTX_PE_File;
    FILE *CTX_IM_File;
    int  PE_Counter;
    int  Error_Counter;
    int  Warning_Counter;
    FILE *LDM_File;
    FILE *common_File;
    U32  LDM_Offset;
};

volatile struct MY_IP_info_t MY_IP_info;

/* =========================
 * Helpers
 * ========================= */
static int filter_uio(const struct dirent *dir)
{
    return (dir->d_name[0] != '.');
}

static int read_uio_name(const char *uio_name, char *buf, size_t buf_size)
{
    char path[128];
    FILE *fp;

    snprintf(path, sizeof(path), "/sys/class/uio/%s/name", uio_name);
    fp = fopen(path, "r");
    if (fp == NULL)
        return 0;

    if (fgets(buf, buf_size, fp) == NULL) {
        fclose(fp);
        return 0;
    }

    fclose(fp);
    return 1;
}

static int is_target_dev(const char *uio_name, const char *target)
{
    char name[64];

    if (!read_uio_name(uio_name, name, sizeof(name)))
        return 0;

    return strcmp(name, target) == 0;
}

static U64 get_reg_size(const char *uio_name)
{
    char path[128];
    char size_str[64];
    FILE *fp;

    snprintf(path, sizeof(path), "/sys/class/uio/%s/maps/map0/size", uio_name);
    fp = fopen(path, "r");
    if (fp == NULL)
        return 0;

    if (fgets(size_str, sizeof(size_str), fp) == NULL) {
        fclose(fp);
        return 0;
    }

    fclose(fp);
    return strtoull(size_str, NULL, 16);
}

static int open_uio_fd(const char *uio_name)
{
    char path[128];

    snprintf(path, sizeof(path), "/dev/%s", uio_name);
    return open(path, O_RDWR | O_SYNC);
}

static void dma_init_regs(struct dma_ctrl *dma)
{
    dma->ZDMA_ERR_CTRL          = 0x00000001;
    dma->ZDMA_CH_ISR            = 0x00000000;
    dma->ZDMA_CH_IMR            = 0x00000FFF;
    dma->ZDMA_CH_IEN            = 0x00000000;
    dma->ZDMA_CH_IDS            = 0x00000000;
    dma->ZDMA_CH_CTRL0          = 0x00000080;
    dma->ZDMA_CH_CTRL1          = 0x000003FF;
    dma->ZDMA_CH_FCI            = 0x00000000;
    dma->ZDMA_CH_STATUS         = 0x00000000;
    dma->ZDMA_CH_DATA_ATTR      = 0x04C3D30F; /* Xilinx recommended AxCACHE */
    dma->ZDMA_CH_DSCR_ATTR      = 0x00000000;

    dma->ZDMA_CH_SRC_DSCR_WORD0 = 0x00000000;
    dma->ZDMA_CH_SRC_DSCR_WORD1 = 0x00000000;
    dma->ZDMA_CH_SRC_DSCR_WORD2 = 0x00000000;
    dma->ZDMA_CH_SRC_DSCR_WORD3 = 0x00000000;
    dma->ZDMA_CH_DST_DSCR_WORD0 = 0x00000000;
    dma->ZDMA_CH_DST_DSCR_WORD1 = 0x00000000;
    dma->ZDMA_CH_DST_DSCR_WORD2 = 0x00000000;
    dma->ZDMA_CH_DST_DSCR_WORD3 = 0x00000000;

    dma->ZDMA_CH_WR_ONLY_WORD0  = 0x00000000;
    dma->ZDMA_CH_WR_ONLY_WORD1  = 0x00000000;
    dma->ZDMA_CH_WR_ONLY_WORD2  = 0x00000000;
    dma->ZDMA_CH_WR_ONLY_WORD3  = 0x00000000;
    dma->ZDMA_CH_SRC_START_LSB  = 0x00000000;
    dma->ZDMA_CH_SRC_START_MSB  = 0x00000000;
    dma->ZDMA_CH_DST_START_LSB  = 0x00000000;
    dma->ZDMA_CH_DST_START_MSB  = 0x00000000;

    dma->ZDMA_CH_RATE_CTRL      = 0x00000000;
    dma->ZDMA_CH_IRQ_SRC_ACCT   = 0x00000000;
    dma->ZDMA_CH_IRQ_DST_ACCT   = 0x00000000;
    dma->ZDMA_CH_CTRL2          = 0x00000000;
}

static int dma_wait_done(struct dma_ctrl *dma)
{
    int status;

    do {
        status = dma->ZDMA_CH_STATUS & 0x3;
    } while (status != 0 && status != 3);

    return status;
}

static void dma_transfer(U64 src_phys, U64 dst_phys, U64 bytes)
{
    struct dma_ctrl *dma = (struct dma_ctrl *)(uintptr_t)my_ip.dma_ctrl;

    *(U64 *)&dma->ZDMA_CH_SRC_DSCR_WORD0 = src_phys;
    dma->ZDMA_CH_SRC_DSCR_WORD2 = (U32)bytes;

    *(U64 *)&dma->ZDMA_CH_DST_DSCR_WORD0 = dst_phys;
    dma->ZDMA_CH_DST_DSCR_WORD2 = (U32)bytes;

    dma->ZDMA_CH_CTRL2 = 1;
    dma_wait_done(dma);
}

/* =========================
 * Public API
 * ========================= */
int my_ip_open(void)
{
    struct dirent **namelist = NULL;
    int num_dirs;
    int i;
    int fd_dma_found = 0;

    const char *UIO_DMA      = "dma-controller\n";
    const char *UIO_AXI_MYIP = "MY_IP\n";
    const char *UIO_DDR_HIGH = "ddr_high\n";

    num_dirs = scandir("/sys/class/uio", &namelist, filter_uio, alphasort);
    if (num_dirs == -1)
        return -1;

    for (i = 0; i < num_dirs; ++i) {
        char *uio = namelist[i]->d_name;
        int fd;
        U64 reg_size = 0;

        if (!fd_dma_found &&
            is_target_dev(uio, UIO_DMA) &&
            (reg_size = get_reg_size(uio)) != 0) {

            if (strlen(uio) > 4) {   /* ignore names like uio10, uio11 if desired */
                free(namelist[i]);
                continue;
            }

            fd = open_uio_fd(uio);
            if (fd >= 0) {
                MY_IP_info.dma_phys = DMA_BASE_PHYS;
                MY_IP_info.dma_mmap = (U64)(uintptr_t)mmap(
                    NULL,
                    reg_size,
                    PROT_READ | PROT_WRITE,
                    MAP_SHARED,
                    fd,
                    0
                );
                close(fd);

                if ((void *)(uintptr_t)MY_IP_info.dma_mmap != MAP_FAILED) {
                    fd_dma_found = 1;
                    printf("/dev/%s: %s", uio, UIO_DMA);
                }
            }
        }
        else if (is_target_dev(uio, UIO_AXI_MYIP)) {
            fd = open_uio_fd(uio);
            if (fd < 0) {
                printf("open failed: %s", UIO_AXI_MYIP);
                free(namelist[i]);
                goto fail;
            }

            printf("/dev/%s: %s", uio, UIO_AXI_MYIP);

            MY_IP_info.reg_phys = REG_BASE_PHYS;
            MY_IP_info.pio_mmap = (U32 *)mmap(
                NULL,
                REG_MMAP_SIZE,
                PROT_READ | PROT_WRITE,
                MAP_SHARED,
                fd,
                0
            );
            if (MY_IP_info.pio_mmap == MAP_FAILED) {
                printf("pio_mmap failed. errno=%d\n", errno);
                close(fd);
                free(namelist[i]);
                goto fail;
            }

            close(fd);

            MY_IP_info.lmm_phys = LMM_BASE_PHYS;
            MY_IP_info.lmm_mmap = (LMM_BASE_PHYS - REG_BASE_PHYS);
        }
        else if (is_target_dev(uio, UIO_DDR_HIGH)) {
            fd = open_uio_fd(uio);
            if (fd < 0) {
                printf("open failed: %s", UIO_DDR_HIGH);
                free(namelist[i]);
                goto fail;
            }

            printf("/dev/%s: %s", uio, UIO_DDR_HIGH);

            MY_IP_info.ddr_phys = DDR_BASE_PHYS;
            MY_IP_info.ddr_mmap = (U64)(uintptr_t)mmap(
                NULL,
                DDR_MMAP_SIZE,
                PROT_READ | PROT_WRITE,
                MAP_SHARED,
                fd,
                0
            );
            close(fd);

            if ((void *)(uintptr_t)MY_IP_info.ddr_mmap == MAP_FAILED) {
                printf("ddr_mmap failed. errno=%d\n", errno);
                free(namelist[i]);
                goto fail;
            }
        }

        free(namelist[i]);
    }

    free(namelist);

    if (fd_dma_found) {
        my_ip.dma_ctrl = MY_IP_info.dma_mmap;
        dma_init_regs((struct dma_ctrl *)(uintptr_t)MY_IP_info.dma_mmap);
    }

    return 1;

fail:
    if (namelist != NULL) {
        while (++i < num_dirs)
            free(namelist[i]);
        free(namelist);
    }
    return -1;
}

/* =========================
 * DMA APIs
 * ========================= */
void dma_write_U32(U64 offset, U64 size)
{
    U64 bytes = size * 8 * sizeof(U32);
    dma_transfer(DDR_BASE_PHYS + offset, LMM_BASE_PHYS + offset, bytes);
}

void dma_read_U32(U64 offset, U64 size)
{
    U64 bytes = size * 8 * sizeof(U32);
    dma_transfer(LMM_BASE_PHYS + offset, DDR_BASE_PHYS + offset, bytes);
}

void dma_write_U64(U64 offset, U64 size)
{
    U64 bytes = size * 4 * sizeof(U64);
    dma_transfer(DDR_BASE_PHYS + offset, LMM_BASE_PHYS + offset, bytes);
}

void dma_read_U64(U64 offset, U64 size)
{
    U64 bytes = size * 4 * sizeof(U64);
    dma_transfer(LMM_BASE_PHYS + offset, DDR_BASE_PHYS + offset, bytes);
}