debian-homelab-framework/
│
├── README.md
├── LICENSE
├── CHANGELOG.md
├── CONTRIBUTING.md
├── ROADMAP.md
├── SECURITY.md
├── CODE_OF_CONDUCT.md
├── VERSION
│
├── scripts/
│
│   00-init-project.sh
│   01-bootstrap.sh
│   02-check-system.sh
│   03-update-system.sh
│
│   10-base-system.sh
│   20-network.sh
│   30-storage.sh
│   40-kvm.sh
│   50-cockpit.sh
│   60-security.sh
│   70-monitoring.sh
│   80-backup.sh
│   90-maintenance.sh
│
├── lib/
│
│   common.sh
│   logger.sh
│   colors.sh
│   output.sh
│   spinner.sh
│   progress.sh
│
│   validation.sh
│   package.sh
│   network.sh
│   system.sh
│   storage.sh
│   security.sh
│
├── configs/
│
│   default.conf
│   packages.conf
│   network.conf
│   storage.conf
│
├── templates/
│
│   sshd_config
│   nftables.conf
│   sysctl.conf
│
├── reports/
│
├── logs/
│
├── backups/
│
├── tests/
│
└── docs/